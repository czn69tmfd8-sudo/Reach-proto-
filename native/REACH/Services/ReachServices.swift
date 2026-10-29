import Foundation

protocol PartnershipService {
    func observePartnership() -> AsyncStream<Partnership?>
}

protocol ReachSessionService {
    func observeSession(partnershipID: String) -> AsyncStream<ReachSession?>
    func openHand(partnership: Partnership) async throws -> ReachSession
    func takeHand(session: ReachSession, partnership: Partnership) async throws
    func end(session: ReachSession) async
}

protocol MediaService {
    func requestPermission() async -> MediaPermissionState
    func prepare() async throws
    func connect(to session: ReachSession, as role: ReachRole) async throws
    func disconnect() async
}

enum ReachRole {
    case opener
    case partner
}
