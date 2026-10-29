import Foundation

enum ReachMediaRole: Equatable {
    case opener
    case joiner
}

enum ReachMediaAction: Equatable {
    case prepareLocalMedia
    case publishOffer
    case awaitOffer
    case publishAnswer
    case exchangeCandidates
    case verifyTransport
    case restorePresentation
    case stopMedia
}

enum ReachMediaPolicy {
    static func initialActions(for role: ReachMediaRole) -> [ReachMediaAction] {
        switch role {
        case .opener:
            return [.prepareLocalMedia, .publishOffer, .exchangeCandidates]
        case .joiner:
            return [.prepareLocalMedia, .awaitOffer, .publishAnswer, .exchangeCandidates]
        }
    }

    static func recoveryActions(
        lifecycle: AppLifecycleState,
        phase: ReachSessionPhase
    ) -> [ReachMediaAction] {
        switch SessionContinuityPolicy.action(
            lifecycle: lifecycle,
            sessionPhase: phase
        ) {
        case .none:
            return []
        case .verifyTransport:
            return [.verifyTransport]
        case .restorePresentation:
            return [.restorePresentation]
        case .markInterrupted:
            return [.verifyTransport]
        }
    }
}
