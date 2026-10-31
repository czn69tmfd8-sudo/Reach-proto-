import Foundation

enum ReachConnectionHealth: Equatable {
    case idle
    case negotiating
    case healthy
    case degraded
    case disconnected
    case failed(String)
}

struct ReachConnectionHealthPolicy {
    static func evaluate(
        signaling: ReachSignalingState,
        media: ReachMediaTransportState
    ) -> ReachConnectionHealth {
        switch media {
        case .failed(let reason):
            return .failed(reason)
        case .connected:
            return .healthy
        case .interrupted:
            return .degraded
        case .preparing, .connecting:
            return .negotiating
        case .idle:
            switch signaling {
            case .idle:
                return .idle
            case .failed(let reason):
                return .failed(reason)
            default:
                return .disconnected
            }
        }
    }
}
