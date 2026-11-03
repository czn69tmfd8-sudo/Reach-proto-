import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            ReachHomeView()
                .tabItem { Label("Reach", systemImage: "heart.fill") }
                .tag(AppTab.reach)

            StagingConnectionView()
                .tabItem { Label("Staging", systemImage: "network") }
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
    private enum Action: Equatable, Sendable {
        case refresh, create, accept(String), revoke(String)
    }

    private struct Status: Sendable {
        let message: String
        var invitation: String?
        var revocableCode: String?
        var canPair = false
    }

    @State private var status = Status(message: "Checking staging pairing…")
    @State private var input = ""
    @State private var action: Action? = .refresh
    @State private var confirmRevocation = false
    @State private var error: String?

    var body: some View {
        Form {
            Section("REACH Test Zone") {
                Text(status.message)
                if let invitation = status.invitation {
                    Text(invitation).font(.title2.monospaced()).textSelection(.enabled)
                    Text("Share this code privately with your partner.")
                }
                if let error { Text(error).foregroundStyle(.red) }
                Button("Refresh status") { action = .refresh }
            }
            if status.canPair {
                Section("Pair with your partner") {
                    Button("Create pairing code") { action = .create }
                    TextField("Partner’s pairing code", text: $input)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    Button("Accept pairing code") {
                        action = .accept(input.trimmingCharacters(in: .whitespacesAndNewlines).uppercased())
                    }
                    .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).count != 12)
                }
            }
            if let code = status.revocableCode {
                Section {
                    Button("Revoke authorization", role: .destructive) { confirmRevocation = true }
                        .confirmationDialog("Revoke this staging pairing?", isPresented: $confirmRevocation) {
                            Button("Revoke pairing", role: .destructive) { action = .revoke(code) }
                        } message: {
                            Text("The partnership will lose authorization. This installation’s membership lock will remain.")
                        }
                }
            }
        }
        .disabled(action != nil)
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

    private nonisolated static func perform(_ action: Action) async throws -> Status {
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
        case .create:
            let code = try await pairs.createInvitation()
            return Status(message: "Waiting for your partner.", invitation: code, revocableCode: code)
        case .accept(let code):
            try await pairs.acceptInvitation(code: code)
        case .revoke(let code):
            try await pairs.revokeInvitation(code: code)
            return Status(message: "Staging pairing revoked.")
        }

        let lock = try await pairs.memberLock(uid: uid)
        guard let lock else {
            return Status(message: "This installation has no staging pairing.", canPair: true)
        }
        let pair = try await pairs.pair(code: lock.pairCode)
        switch PairingAuthorization.resolve(uid: uid, memberLock: lock, pairCode: lock.pairCode, pair: pair) {
        case .authorized:
            return Status(message: "Paired and authorized in staging.", revocableCode: lock.pairCode)
        case .pairRevoked:
            return Status(message: "Staging pairing revoked.")
        case .pairIncomplete:
            return Status(message: "Waiting for your partner.", invitation: lock.pairCode, revocableCode: lock.pairCode)
        case .noMemberLock, .pairMissing, .memberMismatch:
            return Status(message: "This installation’s staging pairing could not be authorized.")
        }
    }
}
