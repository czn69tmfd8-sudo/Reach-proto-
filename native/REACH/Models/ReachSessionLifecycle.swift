import Foundation

enum ReachSessionLifecycleDecision: Equatable {
    case create
    case reuse(ReachSession)
    case reject(String)
}

enum ReachSessionLifecycle {
    static func openingDecision(
        existing: ReachSession?,
        partnership: Partnership,
        now: Date = Date()
    ) -> ReachSessionLifecycleDecision {
        guard partnership.isAuthorized else {
            return .reject("Partnership is not authorized.")
        }

        guard let existing else { return .create }
        guard existing.partnershipID == partnership.id else {
            return .reject("Another partnership session is active.")
        }

        let freshness = ReachSessionFreshnessPolicy.evaluate(
            openedAt: existing.openedAt,
            now: now
        )

        if freshness != .current || existing.phase == .ended {
            return .create
        }

        if existing.openedBy == partnership.localMemberID {
            switch existing.phase {
            case .open, .connecting, .live, .recovering:
                return .reuse(existing)
            case .ended, .failed:
                return .create
            }
        }

        switch existing.phase {
        case .open, .connecting, .live, .recovering:
            return .reject("Your partner already has an active REACH.")
        case .ended, .failed:
            return .create
        }
    }
}

struct ReachCleanupToken: Equatable {
    let partnershipID: String
    let sessionID: String
}

enum ReachCleanupPolicy {
    static func token(
        for session: ReachSession?,
        partnership: Partnership?
    ) -> ReachCleanupToken? {
        guard let session, let partnership else { return nil }
        guard session.partnershipID == partnership.id else { return nil }
        return ReachCleanupToken(
            partnershipID: partnership.id,
            sessionID: session.id
        )
    }

    static func shouldClearPairPointer(
        token: ReachCleanupToken,
        currentActiveRoom: String?
    ) -> Bool {
        currentActiveRoom == token.sessionID
    }
}
