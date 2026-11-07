import Foundation

enum ReachSignalingState: Equatable {
    case idle
    case roomPublished
    case offerPublished
    case answerObserved
    case candidatesExchanging
    case complete
    case failed(String)
}

enum ReachMediaTransportState: Equatable {
    case idle
    case preparing
    case connecting
    case connected
    case interrupted
    case failed(String)
}

struct ReachRuntimeState: Equatable {
    var signaling: ReachSignalingState = .idle
    var media: ReachMediaTransportState = .idle

    var isActuallyConnected: Bool {
        media == .connected
    }

    var isStillNegotiating: Bool {
        switch media {
        case .preparing, .connecting:
            return true
        default:
            return false
        }
    }
}
