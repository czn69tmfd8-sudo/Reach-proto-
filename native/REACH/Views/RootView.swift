import FirebaseAuth
import SwiftUI
import UIKit

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var appearance = ReachAppearanceStore()
    @StateObject private var journal = RelationshipJournalStore()
    @State private var homeNavigationID = UUID()

    @MainActor private static let glowingHeart: UIImage = {
        let size = CGSize(width: 28, height: 28)
        let heart = UIImage(systemName: "heart.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 19, weight: .semibold))
        return UIGraphicsImageRenderer(size: size).image { context in
            guard let heart else { return }
            let origin = CGPoint(x: (size.width - heart.size.width) / 2, y: (size.height - heart.size.height) / 2)
            context.cgContext.setShadow(offset: .zero, blur: 5, color: UIColor.systemPink.cgColor)
            heart.withTintColor(.systemPink, renderingMode: .alwaysOriginal).draw(at: origin)
        }.withRenderingMode(.alwaysOriginal)
    }()

    private enum Action: Equatable, Sendable {
        case refresh(UUID = UUID()), create, accept(String), revoke(String), clearOwnSession(String)

        var isRefresh: Bool {
            if case .refresh = self { return true }
            return false
        }
    }
    private struct RoomCheck: Sendable {
        let id: String
        let pair: PairRecord
        let partnership: Partnership
        let store: any ReachRoomStore
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
        var verifiedUID: String?
        var roomCheck: RoomCheck?
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
    @State private var authenticatedUID: String?
    @State private var pairRead: ReachHomeReadOutcome?
    @State private var roomRead: ReachHomeReadOutcome?
    @State private var input = ""
    @State private var action: Action? = .refresh()
    @State private var confirmRevocation = false
    @State private var mediaStopID = UUID()
    @State private var error: String?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            tabs(now: timeline.date)
        }
        .background(ReachKeyboardObserver().frame(width: 0, height: 0))
        .environmentObject(appearance)
        .environmentObject(journal)
        .tint(.pink)
        .task(id: action) {
            guard let action else { return }
            error = nil
            do {
                let updated: Status
                if action.isRefresh {
                    updated = try await ReachHomeAvailability.boundedRefresh { try await Self.perform(action) }
                } else {
                    updated = try await Self.perform(action)
                }
                guard !Task.isCancelled, self.action == action else { return }
                if action.isRefresh && scenePhase != .active {
                    self.action = nil
                    return
                }
                let previous = status
                status = updated
                pairRead = updated.isPaired ? .verified : .unavailable
                roomRead = nil
                if let check = updated.roomCheck {
                    if previous.verifiedUID == updated.verifiedUID,
                       previous.revocableCode == updated.revocableCode,
                       previous.roomID == updated.roomID,
                       previous.ownRoomID == updated.ownRoomID,
                       previous.availability.paired(at: Date()) || previous.availability.state == .unavailable {
                        status.availability = previous.availability
                    }
                    roomRead = .checking
                    let room: Result<RoomRecord?, Error>
                    do {
                        room = .success(try await ReachHomeAvailability.boundedRefresh {
                            try await check.store.room(id: check.id)
                        })
                    } catch {
                        room = .failure(error)
                    }
                    guard !Task.isCancelled, self.action == action, scenePhase == .active else {
                        if !Task.isCancelled, self.action == action { self.action = nil }
                        return
                    }
                    guard Auth.auth().currentUser?.uid == updated.verifiedUID else {
                        throw StagingCallPreflightError.notAuthorized
                    }
                    switch room {
                    case .success(let record):
                        let now = Date()
                        status.availability = ReachHomeAvailability.afterRoomCheck(
                            partnership: check.partnership, pair: check.pair, room: record,
                            pairCheckedAt: updated.checkedAt, now: now
                        )
                        roomRead = status.availability.paired(at: now) ? .verified : .unavailable
                    case .failure(let error):
                        let outcome = ReachHomeReadOutcome(error: error)
                        roomRead = outcome
                        status.availability = ReachHomeAvailability.afterRoomReadFailure(outcome)
                    }
                }
                if case .accept = action { input = "" }
            } catch {
                guard !Task.isCancelled, self.action == action else { return }
                let outcome = ReachHomeReadOutcome(error: error)
                if action.isRefresh {
                    pairRead = outcome
                    roomRead = nil
                }
                let transient = action.isRefresh && outcome.isTransient
                if let recovery = status.availability.afterRefreshFailure(
                    transient: transient, knownRelationship: hasKnownRelationship, now: Date()
                ) {
                    status.availability = recovery
                    self.action = nil
                    return
                }
                self.error = error is CallbackDeadlineError
                    ? "Connection check timed out. REACH will retry."
                    : ReachErrorPresentation.message(error)
                if action.isRefresh {
                    status = Status(message: "This installation’s staging pairing could not be verified.")
                } else {
                    status.availability = .unavailable
                    status.isPaired = false
                }
            }
            self.action = nil
        }
        .task {
            guard (try? FirebaseBootstrap.configureStaging()) != nil else { return }
            let auth = Auth.auth()
            let (changes, continuation) = AsyncStream<Void>.makeStream()
            let handle = auth.addStateDidChangeListener { _, _ in continuation.yield(()) }
            defer { auth.removeStateDidChangeListener(handle) }
            for await _ in changes {
                authenticatedUID = auth.currentUser?.uid
                if let verifiedUID = status.verifiedUID, verifiedUID != authenticatedUID {
                    status = Status(message: "Checking staging pairing…", availability: .checking)
                    pairRead = nil
                    roomRead = nil
                    if scenePhase == .active && (action == nil || action?.isRefresh == true) {
                        action = .refresh()
                    }
                }
            }
        }
        // Read-only availability refresh. No joining, media start or lock changes.
        .task {
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(5)) } catch { return }
                if scenePhase == .active && action == nil { action = .refresh() }
            }
        }
        .onChange(of: call.phase) { previous, phase in
            if phase == .ending || previous == .ending {
                status.availability = .checking
                if scenePhase == .active && (action == nil || action?.isRefresh == true) {
                    action = .refresh()
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                status.availability = .checking
                if action?.isRefresh == true { action = nil }
            } else if action == nil {
                action = .refresh()
            }
        }
    }

    private var hasKnownRelationship: Bool {
        status.isPaired && status.verifiedUID != nil && status.verifiedUID == authenticatedUID
    }

    private var callScope: ReachCallPairScope? {
        guard scenePhase == .active, hasKnownRelationship,
              let uid = status.verifiedUID, let code = status.revocableCode else { return nil }
        return ReachCallPairScope(uid: uid, code: code)
    }

    private var callAvailability: ReachHomeAvailability {
        status.isPaired && callScope == nil ? .checking : status.availability
    }

    private func tabs(now: Date) -> some View {
        let incoming = scenePhase == .active && ReachHandControls(
            availability: callAvailability, now: now, phase: call.phase,
            roomID: status.roomID, busy: call.busy || (action != nil && action?.isRefresh != true)
        ).canTake
        return TabView(selection: Binding(get: { appState.selectedTab }, set: { tab in
            if tab == .reach && incoming {
                // Reveal the hand card even if Home was left on a detail screen.
                homeNavigationID = UUID()
            }
            appState.selectedTab = tab
        })) {
            homeTab(now: now)
                .tabItem {
                    Label {
                        Text("Reach")
                    } icon: {
                        if incoming {
                            Image(uiImage: Self.glowingHeart).renderingMode(.original)
                        } else {
                            Image(systemName: "heart.fill")
                        }
                    }
                    .accessibilityLabel(incoming ? "Reach, their hand is open" : "Reach")
                }
                .tag(AppTab.reach)
            NavigationStack { TogetherView() }
                .tabItem { Label("Together", systemImage: "sparkles") }.tag(AppTab.together)
            NavigationStack { ReachUsView() }
                .tabItem { Label("Us", systemImage: "person.2.fill") }.tag(AppTab.us)
        }
    }

    @ViewBuilder private func homeTab(now: Date) -> some View {
        let paired = scenePhase == .active && hasKnownRelationship
        let fresh = paired && ReachHomeAvailability.pairingIsFresh(checkedAt: status.checkedAt, now: now)
        #if REACH_SHARED_PROFILE_PHOTOS
        // Keep photo state above the navigation stack, so pushing Messenger
        // cannot tear down the Home portraits or their authorization checks.
        SharedProfilePhotographs(editable: false, enabled: fresh, expectedPairCode: status.revocableCode) { own, partner in
            NavigationStack { home(now: now, paired: paired, pairingVerified: fresh, own: own, partner: partner) }
                .id(homeNavigationID)
        }
        #else
        NavigationStack { home(now: now, paired: paired, pairingVerified: fresh, own: nil, partner: nil) }
            .id(homeNavigationID)
        #endif
    }

    private func home(now: Date, paired: Bool, pairingVerified: Bool, own: UIImage?, partner: UIImage?) -> some View {
        ReachPage {
            homeHeader
            ReachHomeIdentityHeader(paired: paired, pairingVerified: pairingVerified, own: own, partner: partner)
                .shadow(color: .black.opacity(0.7), radius: 5)
            let scope = callScope
            StagingCallView(call: call, stopID: mediaStopID, availability: callAvailability,
                            roomID: status.roomID, scope: scope, now: now,
                            openPreflight: callAvailability.allowsOpenPreflight(
                                knownPair: scope != nil, pairRead: pairRead, roomRead: roomRead, now: now
                            ), pairingBusy: action != nil && action?.isRefresh != true) { roomID in
                action = .clearOwnSession(roomID)
            }
            if call.phase.showsHandCards && (!status.isPaired || status.availability.state == .unavailable) {
                Button(status.canPair ? "Set up pairing" : "Manage pairing") { menuPage = .pairing }
                    .buttonStyle(.bordered).tint(.white).frame(minHeight: 44)
            }
            if let error { Text(error).font(.footnote).multilineTextAlignment(.center) }
            ReachDailyMomentView(now: now)
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $menuPage) { page in
            NavigationStack {
                ReachPage {
                    if page == .pairing { pairingPanel }
                    else { ReachConnectionInformation(page: page.rawValue, call: call, pairRead: pairRead, roomRead: roomRead) }
                }
                .navigationTitle(page.title).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { menuPage = nil } } }
            }
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
                        Button("Refresh availability") { action = .refresh() }.frame(minHeight: 44)
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

        try Task.checkCancellation()
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
        let checkedAt = Date()
        try Task.checkCancellation()
        guard await dependencies.auth.currentUID() == uid else { throw StagingCallPreflightError.notAuthorized }
        switch PairingAuthorization.resolve(uid: uid, memberLock: lock, pairCode: lock.pairCode, pair: pair) {
        case .authorized(let partnership):
            guard let pair else { return Status(message: "Pairing could not be verified.") }
            let roomCheck = pair.activeRoom.map { RoomCheck(id: $0, pair: pair, partnership: partnership, store: dependencies.rooms) }
            let availability: ReachHomeAvailability = roomCheck != nil ? .checking : .afterRoomCheck(
                partnership: partnership, pair: pair, room: nil, pairCheckedAt: checkedAt, now: checkedAt
            )
            return Status(message: "Paired and authorized in staging.", revocableCode: lock.pairCode,
                          roomID: pair.activeRoom, ownRoomID: pair.openedBy == uid ? pair.activeRoom : nil,
                          isPaired: true, availability: availability, checkedAt: checkedAt,
                          verifiedUID: uid, roomCheck: roomCheck)
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
