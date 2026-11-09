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
            let latest = await backend.currentSession()
            guard case .create = ReachSessionLifecycle.openingDecision(
                existing: latest,
                partnership: partnership
            ) else {
                errorMessage = "Another REACH session was opened while preparing your connection."
                return
            }
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
            let latestSession = await backend.currentSession()
            guard latestSession == session,
                  ReachJoinPolicy.decide(session: latestSession, partnership: partnership) == .allowed else {
                errorMessage = "This REACH is no longer available."
                state.session = latestSession
                return
            }
            state.session = ReachConnectionMachine.reduce(state.session, event: .connectionStarted)
            if let connecting = state.session {
                guard await backend.updateIfCurrent(connecting, expectedID: session.id) else {
                    state.session = await backend.currentSession()
                    errorMessage = "This REACH ended before connecting."
                    return
                }
            }
            try await media.connect(to: session, as: .partner)
            guard let latest = await backend.currentSession(), latest.id == session.id else {
                await media.disconnect()
                state.session = await backend.currentSession()
                errorMessage = "This REACH ended while connecting."
                return
            }
            state.session = ReachConnectionMachine.reduce(state.session, event: .mediaConnected)
            if let live = state.session {
                let applied = await backend.updateIfCurrent(live, expectedID: session.id)
                if !applied {
                    await media.disconnect()
                    state.session = await backend.currentSession()
                    errorMessage = "This REACH ended while completing the connection."
                }
            }
        } catch {
            await media.disconnect()
            let latest = await backend.currentSession()
            if latest?.id == session.id {
                let failed = ReachConnectionMachine.reduce(latest, event: .failed(error.localizedDescription))
                if let failed {
                    _ = await backend.updateIfCurrent(failed, expectedID: session.id)
                }
            }
            state.session = await backend.currentSession()
            errorMessage = error.localizedDescription
        }
    }

    func transportInterrupted() async {
        guard let current = state.session else { return }
        guard let latest = await backend.currentSession(), latest.id == current.id else {
            state.session = await backend.currentSession()
            return
        }
        if let interrupted = ReachConnectionMachine.reduce(latest, event: .connectionInterrupted) {
            _ = await backend.updateIfCurrent(interrupted, expectedID: latest.id)
        }
        state.session = await backend.currentSession()
    }

    func transportRecovered() async {
        guard let current = state.session else { return }
        guard let latest = await backend.currentSession(), latest.id == current.id else {
            state.session = await backend.currentSession()
            return
        }
        if let recovered = ReachConnectionMachine.reduce(latest, event: .connectionRecovered) {
            _ = await backend.updateIfCurrent(recovered, expectedID: latest.id)
        }
        state.session = await backend.currentSession()
    }

    func endReach() async {
        guard !isBusy, state.session != nil else { return }
        isBusy = true
        defer { isBusy = false }

        let endingID = state.session?.id
        await media.disconnect()
        if let endingID {
            _ = await backend.clearIfCurrent(id: endingID)
        }
        state.session = await backend.currentSession()
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

