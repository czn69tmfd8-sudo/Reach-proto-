import Foundation

@MainActor
final class ReachCoordinator: ObservableObject {
    @Published private(set) var state: ConnectionState
    @Published var errorMessage: String?
    @Published private(set) var isBusy = false

    private let media: MediaService
    private let backend: MockReachBackend

    init(
        state: ConnectionState = ConnectionState(),
        media: MediaService = MockMediaService(),
        backend: MockReachBackend = .shared
    ) {
        self.state = state
        self.media = media
        self.backend = backend
    }

    func bootstrap() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }

        // Development identity only. The production Firebase adapter will replace this.
        if state.partnership == nil {
            state.partnership = Partnership(
                id: "dev-pair",
                localMemberID: "local-device",
                partnerMemberID: "partner-device",
                partnerDisplayName: "Partner",
                isAuthorized: true
            )
        }

        // Permission prompts belong to the user's explicit attempt to open or join.
        // Bootstrapping the home screen must not activate camera/microphone prompts.
        state.session = await backend.currentSession()
    }

    func refresh() async {
        state.session = await backend.currentSession()
    }

    func openHand() async {
        guard !isBusy else { return }
        guard let partnership = state.partnership, partnership.isAuthorized else {
            errorMessage = "Pair with your partner before opening your hand."
            return
        }
        guard case .create = ReachSessionLifecycle.openingDecision(
            existing: state.session,
            partnership: partnership
        ) else {
            errorMessage = "A REACH session is already active or needs to be cleared."
            return
        }
        isBusy = true
        defer { isBusy = false }

        do {
            state.mediaPermission = .requesting
            state.mediaPermission = await media.requestPermission()
            guard state.mediaPermission == .granted else {
                errorMessage = "Camera and microphone permission are required."
                return
            }
            try await media.prepare()
            let session = try await backend.open(partnership: partnership)
            state.session = ReachConnectionMachine.reduce(state.session, event: .handOpened(session))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func takeHand() async {
        guard !isBusy else { return }
        guard let session = state.session, let partnership = state.partnership else { return }
        guard ReachJoinPolicy.decide(session: session, partnership: partnership) == .allowed else {
            errorMessage = "This REACH is unavailable, expired, or not authorized for your partnership."
            return
        }

        isBusy = true
        defer { isBusy = false }

        // Do not publish a connecting state until consent and local media are ready.
        // A declined permission request must leave the partner's hand joinable.
        state.mediaPermission = .requesting
        state.mediaPermission = await media.requestPermission()
        guard state.mediaPermission == .granted else {
            errorMessage = "Camera and microphone permission are required to connect."
            return
        }

        do {
            try await media.prepare()
            guard ReachJoinPolicy.decide(session: session, partnership: partnership) == .allowed else {
                errorMessage = "This REACH is no longer available."
                return
            }
            state.session = ReachConnectionMachine.reduce(state.session, event: .connectionStarted)
            if let connecting = state.session { await backend.update(connecting) }
            try await media.connect(to: session, as: .partner)
            state.session = ReachConnectionMachine.reduce(state.session, event: .mediaConnected)
            if let live = state.session { await backend.update(live) }
        } catch {
            state.session = ReachConnectionMachine.reduce(state.session, event: .failed(error.localizedDescription))
            if let failed = state.session { await backend.update(failed) }
            errorMessage = error.localizedDescription
        }
    }

    func transportInterrupted() async {
        state.session = ReachConnectionMachine.reduce(state.session, event: .connectionInterrupted)
        if let session = state.session { await backend.update(session) }
    }

    func transportRecovered() async {
        state.session = ReachConnectionMachine.reduce(state.session, event: .connectionRecovered)
        if let session = state.session { await backend.update(session) }
    }

    func endReach() async {
        guard !isBusy, state.session != nil else { return }
        isBusy = true
        defer { isBusy = false }

        await media.disconnect()
        state.session = ReachConnectionMachine.reduce(state.session, event: .ended)
        await backend.update(nil)
    }

    #if DEBUG
    func simulatePartnerOpeningHand() async {
        guard let partnership = state.partnership else { return }
        let session = ReachSession(
            id: UUID().uuidString,
            partnershipID: partnership.id,
            openedBy: partnership.partnerMemberID,
            openedAt: Date(),
            phase: .open
        )
        await backend.update(session)
        state.session = ReachConnectionMachine.reduce(state.session, event: .partnerHandObserved(session))
    }
    #endif
}

private enum ReachCoordinatorMediaError: LocalizedError {
    case permissionDenied

    var errorDescription: String? {
        "Camera and microphone permission are required to connect."
    }
}
