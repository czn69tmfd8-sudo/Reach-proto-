import Foundation

enum ReachJoinDecision: Equatable {
    case allowed
    case noSession
    case ownHand
    case unauthorizedPair
    case wrongPartnership
    case expired
    case unavailable
}

enum ReachJoinPolicy {
    static func decide(
        session: ReachSession?,
        partnership: Partnership?,
        now: Date = Date()
    ) -> ReachJoinDecision {
        guard let session else { return .noSession }
        guard let partnership, partnership.isAuthorized else { return .unauthorizedPair }
        guard session.partnershipID == partnership.id else { return .wrongPartnership }
        guard session.openedBy != partnership.localMemberID else { return .ownHand }

        guard ReachSessionFreshnessPolicy.evaluate(openedAt: session.openedAt, now: now) == .current
        else { return .expired }

        switch session.phase {
        case .open, .recovering:
            return .allowed
        case .connecting, .live, .ended, .failed:
            return .unavailable
        }
    }
}
