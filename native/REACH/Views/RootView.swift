import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            StagingConnectionView()
                .tabItem { Label("REACH", systemImage: "heart.fill") }
                .tag(AppTab.reach)

            ReachHomeView()
                .tabItem { Label("Demo", systemImage: "heart.fill") }
                .tag(AppTab.together)

            PlaceholderView(title: "Us", subtitle: "Your shared relationship space.")
                .tabItem { Label("Us", systemImage: "sparkles") }
                .tag(AppTab.us)
        }
    }
}

private struct PlaceholderView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Text(title).font(.largeTitle.bold())
            Text(subtitle).multilineTextAlignment(.center).foregroundStyle(.secondary)
        }
        .padding()
    }
}

private struct StagingConnectionView: View {
    @EnvironmentObject private var appState: AppState

    private enum Action: Equatable, Sendable {
        case refresh, create, accept(String), revoke(String), clearOwnSession
    }

    private struct Status: Sendable {
        let message: String
        var invitation: String?
        var revocableCode: String?
        var canPair = false
        var canCloseOwnSession = false
    }

    @State private var status = Status(message: "Checking staging pairing…")
    @State private var input = ""
    @State private var action: Action? = .refresh
    @State private var confirmRevocation = false
    @State private var mediaStopID = UUID()
    @State private var error: String?

    var body: some View {
        ZStack {
            ReachHomeBackground(source: appState.homeBackground)
            Form {
                Section {
                    ReachHomeIdentityHeader()
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                StagingCallView(stopID: mediaStopID)
                    .listRowBackground(panelTint)
                Section("REACH Test Zone") {
                    Text(status.message)
                    if let invitation = status.invitation {
                        Text(invitation).font(.title2.monospaced()).textSelection(.enabled)
                        Text("Share this native staging code privately with your partner. Existing web pairings are kept separate.")
                    }
                    if let error { Text(error).foregroundStyle(.red) }
                    Button("Refresh status") { action = .refresh }.disabled(action != nil)
                    if status.canCloseOwnSession {
                        Button("Close my previously open hand", role: .destructive) { action = .clearOwnSession }
                            .disabled(action != nil)
                    }
                }
                .listRowBackground(panelTint)
                if status.canPair {
                    Section("Pair with your partner") {
                        Button("Create pairing code") { action = .create }.disabled(action != nil)
                        TextField("Partner’s pairing code", text: $input)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                        Button("Accept pairing code") {
                            action = .accept(input.trimmingCharacters(in: .whitespacesAndNewlines).uppercased())
                        }
                        .disabled(action != nil || input.trimmingCharacters(in: .whitespacesAndNewlines).count != 12)
                    }
                    .listRowBackground(panelTint)
                }
                if let code = status.revocableCode {
                    Section {
                        Button("Revoke authorization", role: .destructive) { confirmRevocation = true }
                            .disabled(action != nil)
                            .confirmationDialog("Revoke this staging pairing?", isPresented: $confirmRevocation) {
                                Button("Revoke pairing", role: .destructive) {
                                    mediaStopID = UUID()
                                    action = .revoke(code)
                                }
                            } message: {
                                Text("This pairing and its calls will lose authorization. You can then create or accept a fresh native pairing. Your web pairing stays unchanged.")
                            }
                    }
                    .listRowBackground(panelTint)
                }
            }
            .scrollContentBackground(.hidden)
            .background(.clear)
            .tint(.pink)
            .environment(\.colorScheme, .dark)
        }
        .task(id: action) {
            guard let action else { return }
            error = nil
            do {
                status = try await Self.perform(action)
                if case .accept = action { input = "" }
            } catch {
                self.error = error.localizedDescription
                if case .refresh = action {
                    status = Status(message: "Staging pairing could not be verified.")
                }
            }
            self.action = nil
        }
    }

    private var panelTint: Color {
        Color(red: 0.16, green: 0.08, blue: 0.25).opacity(0.66)
    }

    @MainActor private static func perform(_ action: Action) async throws -> Status {
        let dependencies = try FirebaseDependencyFactory.staging()
        guard let pairs = dependencies.pairs as? FirestorePairStore else {
            return Status(message: "The staging pairing store is unavailable.")
        }
        let uid: String
        if let existing = await dependencies.auth.currentUID() {
            uid = existing
        } else {
            uid = try await dependencies.auth.signInAnonymously()
        }

        switch action {
        case .refresh: break
        case .clearOwnSession:
            guard let lock = try await pairs.memberLock(uid: uid),
                  let pair = try await pairs.pair(code: lock.pairCode),
                  pair.openedBy == uid, let roomID = pair.activeRoom else { throw ReachRoomCoordinatorError.unauthorized }
            try await dependencies.rooms.clearPairSessionIfCurrent(pairCode: lock.pairCode, roomID: roomID)
        case .create:
            let code = try await pairs.createInvitation()
            return Status(message: "Waiting for your partner. This native code expires in 30 minutes.", invitation: code, revocableCode: code)
        case .accept(let code):
            try await pairs.acceptInvitation(code: code)
        case .revoke(let code):
            try await pairs.revokeInvitation(code: code)
            return Status(message: "Native pairing revoked. You can pair again.", canPair: true)
        }

        let lock = try await pairs.memberLock(uid: uid)
        guard let lock else {
            return Status(message: "This installation has no staging pairing.", canPair: true)
        }
        let pair = try await pairs.pair(code: lock.pairCode)
        switch PairingAuthorization.resolve(uid: uid, memberLock: lock, pairCode: lock.pairCode, pair: pair) {
        case .authorized:
            return Status(message: "Paired and authorized in staging.", revocableCode: lock.pairCode, canCloseOwnSession: pair?.openedBy == uid && pair?.activeRoom != nil)
        case .pairRevoked:
            return Status(message: "Native pairing revoked. You can pair again.", canPair: true)
        case .pairIncomplete:
            if let expires = pair?.invitationExpiresAt, expires > Date() {
                return Status(message: "Waiting for your partner. Code expires at \(expires.formatted(date: .omitted, time: .shortened)).", invitation: lock.pairCode, revocableCode: lock.pairCode)
            }
            return Status(message: "Native invitation expired. Revoke it before creating a fresh code.", revocableCode: lock.pairCode)
        case .noMemberLock, .pairMissing, .memberMismatch:
            return Status(message: "This installation’s staging pairing could not be authorized.")
        }
    }
}
