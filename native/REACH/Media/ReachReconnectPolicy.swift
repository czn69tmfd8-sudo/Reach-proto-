import Foundation

enum ReachReconnectDecision: Equatable {
    case wait(TimeInterval)
    case verifyTransport
    case fail
}

enum ReachReconnectPolicy {
    static let delays: [TimeInterval] = [1, 2, 4, 8]

    static func decision(attempt: Int, appIsActive: Bool) -> ReachReconnectDecision {
        guard attempt >= 0 else { return .fail }
        guard appIsActive else { return .verifyTransport }
        guard attempt < delays.count else { return .fail }
        return .wait(delays[attempt])
    }
}
