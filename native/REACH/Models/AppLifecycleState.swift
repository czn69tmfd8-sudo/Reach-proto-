import Foundation

enum ReachAppLifecycleState: Equatable {
    case active
    case inactive
    case background
}

enum SessionContinuityAction: Equatable {
    case none
    case verifyTransport
    case restorePresentation
    case markInterrupted
}

enum SessionContinuityPolicy {
    static func action(
        lifecycle: ReachAppLifecycleState,
        sessionPhase: ReachSessionPhase?
    ) -> SessionContinuityAction {
        guard let sessionPhase else { return .none }

        switch (lifecycle, sessionPhase) {
        case (.active, .recovering):
            return .verifyTransport
        case (.active, .live), (.active, .connecting), (.active, .open):
            return .restorePresentation
        case (.background, .connecting):
            return .markInterrupted
        default:
            return .none
        }
    }
}
