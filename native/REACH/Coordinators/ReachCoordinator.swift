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

        state.mediaPermission = .requesting
        state.mediaPermission = await media.requestPermission()
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
        guard state.mediaPermission == .granted else {
            errorMessage = "Camera and microphone permission are required."
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
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
        guard session.openedBy != partnership.localMemberID else { return }

        isBusy = true
        defer { isBusy = false }

        state.session = ReachConnectionMachine.reduce(state.session, event: .connectionStarted)
        if let connecting = state.session { await backend.update(connecting) }

        do {
            try await media.prepare()
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
