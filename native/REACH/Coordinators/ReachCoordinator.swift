import Foundation

@MainActor
final class ReachCoordinator: ObservableObject {
    @Published private(set) var state: ConnectionState
    @Published var errorMessage: String?

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
        // Development identity only. Firebase auth/pairing replaces this adapter.
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
        guard let partnership = state.partnership, partnership.isAuthorized else {
            errorMessage = "Pair with your partner before opening your hand."
            return
        }
        guard state.mediaPermission == .granted else {
            errorMessage = "Camera and microphone permission are required."
            return
        }

        do {
            try await media.prepare()
            let session = try await backend.open(partnership: partnership)
            state.session = session
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func takeHand() async {
        guard var session = state.session, let partnership = state.partnership else { return }
        guard session.openedBy != partnership.localMemberID else { return }

        do {
            session.phase = .connecting
            state.session = session
            await backend.update(session)
            try await media.prepare()
            try await media.connect(to: session, as: .partner)
            session.phase = .live
            state.session = session
            await backend.update(session)
        } catch {
            session.phase = .failed(error.localizedDescription)
            state.session = session
            await backend.update(session)
            errorMessage = error.localizedDescription
        }
    }

    func endReach() async {
        guard var session = state.session else { return }
        await media.disconnect()
        session.phase = .ended
        state.session = nil
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
        state.session = session
    }
    #endif
}
