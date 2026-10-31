import Foundation

actor MockReachBackend {
    static let shared = MockReachBackend()
    private var session: ReachSession?

    func currentSession() -> ReachSession? { session }

    func open(partnership: Partnership) throws -> ReachSession {
        if let session, session.phase != .ended { return session }
        let created = ReachSession(
            id: UUID().uuidString,
            partnershipID: partnership.id,
            openedBy: partnership.localMemberID,
            openedAt: Date(),
            phase: .open
        )
        session = created
        return created
    }

    func update(_ updated: ReachSession?) { session = updated }
}

struct MockMediaService: MediaService {
    func requestPermission() async -> MediaPermissionState { .granted }
    func prepare() async throws {}
    func connect(to session: ReachSession, as role: ReachRole) async throws {
        try await Task.sleep(for: .milliseconds(650))
    }
    func disconnect() async {}
}
