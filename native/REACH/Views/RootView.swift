import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var appearance = ReachAppearanceStore()
    @StateObject private var journal = RelationshipJournalStore()

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            NavigationStack { StagingConnectionView() }
                .tabItem { Label("Reach", systemImage: "heart.fill") }.tag(AppTab.reach)
            NavigationStack { TogetherView() }
                .tabItem { Label("Together", systemImage: "sparkles") }.tag(AppTab.together)
            NavigationStack { ReachUsView() }
                .tabItem { Label("Us", systemImage: "person.2.fill") }.tag(AppTab.us)
        }
        .background(ReachKeyboardObserver().frame(width: 0, height: 0))
        .environmentObject(appearance)
        .environmentObject(journal)
        .tint(.pink)
    }
}

private struct StagingConnectionView: View {
    private enum Action: Equatable, Sendable {
        case refresh, create, accept(String), revoke(String), clearOwnSession(String)
    }
    private struct Status: Sendable {
        let message: String
        var invitation: String?
        var revocableCode: String?
        var canPair = false
        var roomID: String?
        var ownRoomID: String?
        var isPaired = false
        var availability: ReachHomeAvailability = .unavailable
        var checkedAt = Date()
    }
    private enum MenuPage: String, Identifiable {
        case pairing, connection, privacy, security, about
        var id: String { rawValue }
        var title: String {
            switch self {
            case .pairing: return "Pairing management"
            case .connection: return "Connection information"
            case .privacy: return "Privacy"
            case .security: return "Security"
            case .about: return "About REACH"
            }
        }
    }
    @StateObject private var call = StagingCallController()
    @State private var menuPage: MenuPage?
    @State private var status = Status(message: "Checking staging pairing…", availability: .checking)
    @State private var input = ""
    @State private var action: Action? = .refresh
    @State private var confirmRevocation = false
    @State private var mediaStopID = UUID()
    @State private var error: String?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            ReachPage {
                homeHeader
                ReachHomeIdentityHeader(paired: status.isPaired && status.checkedAt.addingTimeInterval(15) > timeline.date)
                    .shadow(color: .black.opacity(0.7), radius: 5)
                StagingCallView(call: call, stopID: mediaStopID, availability: status.availability,
                                roomID: status.roomID, now: timeline.date, pairingBusy: action != nil && action != .refresh) { roomID in
                    action = .clearOwnSession(roomID)
                }
                if call.phase.showsHandCards && (!status.isPaired || status.availability.state == .unavailable) {
                    Button(status.canPair ? "Set up pairing" : "Manage pairing") { menuPage = .pairing }
                        .buttonStyle(.bordered).tint(.white).frame(minHeight: 44)
                }
                if let error { Text(error).font(.footnote).multilineTextAlignment(.center) }
                ReachDailyMomentView(now: timeline.date)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $menuPage) { page in
            NavigationStack {
                ReachPage {
                    if page == .pairing { pairingPanel }
                    else { ReachConnectionInformation(page: page.rawValue, call: call) }
                }
                .navigationTitle(page.title).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { menuPage = nil } } }
            }
        }
        .task(id: action) {
            guard let action else { return }
            error = nil
            do {
                let updated = try await Self.perform(action)
                guard !Task.isCancelled else { return }
                status = updated
                if case .accept = action { input = "" }
            } catch {
                guard !Task.isCancelled else { return }
                self.error = ReachErrorPresentation.message(error)
                status.availability = .unavailable
                status.isPaired = false
            }
            self.action = nil
        }
        // Read-only availability refresh. No joining, media start or lock changes.
        .task {
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(5)) } catch { return }
                if scenePhase == .active && action == nil { action = .refresh }
            }
        }
        .onChange(of: call.phase) { previous, phase in
            if phase == .ending || previous == .ending {
                status.availability = .checking
                if previous == .ending && action == nil { action = .refresh }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            status.availability = .checking
            if phase == .active && action == nil { action = .refresh }
        }
    }

    private var homeHeader: some View {
        VStack(spacing: 6) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    homeMenu
                    Spacer(minLength: 0)
                    wordmark.fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 0)
                    // Balance the menu so the wordmark stays centered on the page.
                    Color.clear.frame(width: 44, height: 44).accessibilityHidden(true)
                }
                VStack(spacing: 4) {
                    homeMenu.frame(maxWidth: .infinity, alignment: .leading)
                    wordmark
                }
            }
            VStack(spacing: 3) {
                Text("“Let all that you do be done in love.”")
                    .font(.subheadline.weight(.medium))
                    .italic()
                Text("1 Corinthians 16:14")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.85), radius: 5)
            .accessibilityElement(children: .combine)
            Text("PRIVATE STAGING").font(.caption2.weight(.bold)).tracking(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(.black.opacity(0.45), in: Capsule())
        }
        .frame(maxWidth: .infinity)
    }

    private var wordmark: some View {
        Text("REACH").font(.largeTitle.weight(.black)).tracking(5)
            .multilineTextAlignment(.center)
            .foregroundStyle(LinearGradient(colors: [.pink, .purple, .cyan], startPoint: .leading, endPoint: .trailing))
            .accessibilityAddTraits(.isHeader)
    }

    private var homeMenu: some View {
        Menu {
            ForEach([MenuPage.pairing, .connection, .privacy, .security, .about]) { page in
                Button(page.title) { ReachKeyboard.dismiss(); menuPage = page }
            }
        } label: {
            Image(systemName: "line.3.horizontal")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.black.opacity(reduceTransparency ? 0.85 : 0.42), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("REACH menu")
    }

    private var pairingPanel: some View {
        ReachGlassPanel {
            VStack(alignment: .leading, spacing: 16) {
                Label("Your pairing", systemImage: "link").font(.headline)
                Text(status.message).font(.subheadline)
                if let invitation = status.invitation {
                    Text(invitation).font(.title2.monospaced()).textSelection(.enabled)
                    Text("Share this private code with your partner. It belongs only to native staging.")
                        .font(.footnote).foregroundStyle(.white.opacity(0.85))
                }
                if let error { Text(error).font(.footnote).foregroundStyle(.white).accessibilityLabel("Pairing error: " + error) }
                if status.canPair {
                    Button("Create pairing code") { action = .create }
                        .buttonStyle(.borderedProminent).frame(minHeight: 44)
                    TextField("Partner’s pairing code", text: $input)
                        .textInputAutocapitalization(.characters).autocorrectionDisabled()
                        .submitLabel(.done).onSubmit { ReachKeyboard.dismiss() }
                        .textFieldStyle(.roundedBorder).frame(minHeight: 44)
                        .accessibilityLabel("Partner’s 12-character native pairing code")
                    Button("Accept pairing code") {
                        action = .accept(input.trimmingCharacters(in: .whitespacesAndNewlines).uppercased())
                    }
                    .buttonStyle(.bordered)
                    .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).count != 12)
                }
                DisclosureGroup("Manage connection") {
                    VStack(alignment: .leading, spacing: 14) {
                        Button("Refresh availability") { action = .refresh }.frame(minHeight: 44)
                        if let roomID = status.ownRoomID, !call.phase.hasStarted, !call.busy {
                            Button("Close my previously open hand", role: .destructive) {
                                action = .clearOwnSession(roomID)
                            }.frame(minHeight: 44)
                        }
                        if let code = status.revocableCode {
                            Button("Revoke authorization", role: .destructive) { confirmRevocation = true }
                                .frame(minHeight: 44)
                                .confirmationDialog("Revoke this staging pairing?", isPresented: $confirmRevocation) {
                                    Button("Revoke pairing", role: .destructive) {
                                        mediaStopID = UUID()
                                        status.availability = .unavailable
                                        status.isPaired = false
                                        action = .revoke(code)
                                    }
                                } message: {
                                    Text("This pairing and its calls will lose authorization. You can then create or accept a fresh native pairing. Your web pairing stays unchanged.")
                                }
                        }
                    }.padding(.top, 12)
                }
            }
            .disabled(action != nil)
        }
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
        case .clearOwnSession(let roomID):
            guard let lock = try await pairs.memberLock(uid: uid),
                  let pair = try await pairs.pair(code: lock.pairCode),
                  case .authorized(let partnership) = PairingAuthorization.resolve(uid: uid, memberLock: lock, pairCode: lock.pairCode, pair: pair),
                  ReachHandControls.canWithdraw(roomID: roomID, partnership: partnership, pair: pair) else {
                throw ReachRoomCoordinatorError.unauthorized
            }
            try await dependencies.rooms.clearPairSessionIfCurrent(pairCode: lock.pairCode, roomID: roomID)
        case .create:
            let code = try await pairs.createInvitation()
            return Status(message: "Waiting for your partner. This native code expires in 30 minutes.", invitation: code, revocableCode: code, availability: .invitation)
        case .accept(let code):
            try await pairs.acceptInvitation(code: code)
        case .revoke(let code):
            try await pairs.revokeInvitation(code: code)
            return Status(message: "Native pairing revoked. You can pair again.", canPair: true, availability: .unpaired)
        }

        let lock = try await pairs.memberLock(uid: uid)
        guard let lock else {
            return Status(message: "This installation has no staging pairing.", canPair: true, availability: .unpaired)
        }
        let pair = try await pairs.pair(code: lock.pairCode)
        switch PairingAuthorization.resolve(uid: uid, memberLock: lock, pairCode: lock.pairCode, pair: pair) {
        case .authorized(let partnership):
            guard let pair else { return Status(message: "Pairing could not be verified.") }
            // A display read may fail while offline or for a stale/expired room.
            // Never present a joinable hand without a verified current room.
            let room: RoomRecord?
            if let roomID = pair.activeRoom { room = try? await dependencies.rooms.room(id: roomID) }
            else { room = nil }
            return Status(message: "Paired and authorized in staging.", revocableCode: lock.pairCode,
                          roomID: pair.activeRoom, ownRoomID: pair.openedBy == uid ? pair.activeRoom : nil,
                          isPaired: true,
                          availability: ReachHandControls.verifiedAvailability(partnership: partnership, pair: pair, room: room, now: Date()))
        case .pairRevoked:
            return Status(message: "Native pairing revoked. You can pair again.", canPair: true, availability: .unpaired)
        case .pairIncomplete:
            if let expires = pair?.invitationExpiresAt, expires > Date() {
                return Status(message: "Waiting for your partner. Code expires at \(expires.formatted(date: .omitted, time: .shortened)).", invitation: lock.pairCode, revocableCode: lock.pairCode, availability: .invitation)
            }
            return Status(message: "Native invitation expired. Revoke it before creating a fresh code.", revocableCode: lock.pairCode)
        case .noMemberLock, .pairMissing, .memberMismatch:
            return Status(message: "This installation’s staging pairing could not be authorized.")
        }
    }
}
