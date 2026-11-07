import Foundation

actor MockReachBackend {
    static let shared = MockReachBackend()
    private var session: ReachSession?

    func currentSession() -> ReachSession? { session }

    func open(partnership: Partnership) throws -> ReachSession {
        if let session,
           ReachSessionFreshnessPolicy.evaluate(openedAt: session.openedAt) == .current,
           session.phase != .ended {
            throw MockReachBackendError.sessionAlreadyExists
        }
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

    /// Only apply an update if it still refers to the active session.
    /// A delayed media callback must never resurrect a session after it ends.
    @discardableResult
    func updateIfCurrent(_ updated: ReachSession, expectedID: String) -> Bool {
        guard session?.id == expectedID, updated.id == expectedID else { return false }
        session = updated
        return true
    }

    /// Ending a stale call must not erase a newer call.
    @discardableResult
    func clearIfCurrent(id: String) -> Bool {
        guard session?.id == id else { return false }
        session = nil
        return true
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

enum MockReachBackendError: LocalizedError {
    case sessionAlreadyExists

    var errorDescription: String? {
        "An active REACH session already exists."
    }
}
