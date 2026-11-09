import Foundation

/// A fresh room/peer is required after terminal failure. Never auto-join or reuse SDP.
/// Waiting for a partner to take an open hand has no negotiation deadline.
struct ReachTransportWatchdog {
    enum Event { case negotiationStarted, connected, disconnected, failed, closed }
    enum Action: Equatable {
        case none, cancelDeadline
        case startDeadline(UUID, TimeInterval)
        case stop
    }
    static let negotiationTimeout: TimeInterval = 45
    static let interruptionTimeout: TimeInterval = 20
    private(set) var deadlineID: UUID?
    private(set) var finished = false
    private var connected = false

    mutating func receive(_ event: Event) -> Action {
        guard !finished else { return .none }
        switch event {
        case .failed, .closed:
            finished = true; deadlineID = nil
            return .stop
        case .connected:
            connected = true; deadlineID = nil
            return .cancelDeadline
        case .negotiationStarted:
            guard !connected, deadlineID == nil else { return .none }
            return arm(seconds: Self.negotiationTimeout)
        case .disconnected:
            // Repeated SDK callbacks must not indefinitely extend an interruption.
            guard connected, deadlineID == nil else { return .none }
            connected = false
            return arm(seconds: Self.interruptionTimeout)
        }
    }

    mutating func deadlineExpired(_ id: UUID) -> Action {
        guard !finished, deadlineID == id else { return .none }
        finished = true; deadlineID = nil
        return .stop
    }

    private mutating func arm(seconds: TimeInterval) -> Action {
        let id = UUID(); deadlineID = id
        return .startDeadline(id, seconds)
    }
}
