import Foundation

enum ReachCallPhase: Equatable {
    case idle, preparing, outgoing, connecting, connected, interrupted, ending, failed(String)

    var title: String? {
        switch self {
        case .idle: return nil
        case .preparing: return "Preparing to reach…"
        case .outgoing: return "Your hand is open"
        case .connecting: return "Connecting…"
        case .connected: return "Call connected"
        case .interrupted: return "Connection interrupted. Waiting for the network…"
        case .ending: return "Closing connection…"
        case .failed(let message): return message
        }
    }

    var showsHandCards: Bool {
        switch self {
        case .idle, .outgoing, .failed: return true
        default: return false
        }
    }

    var hasStarted: Bool {
        switch self {
        case .preparing, .outgoing, .connecting, .connected, .interrupted: return true
        default: return false
        }
    }

    func receiving(_ event: ReachTransportWatchdog.Event) -> Self {
        guard hasStarted else { return self }
        switch event {
        case .negotiationStarted: return self == .connected || self == .interrupted ? self : .connecting
        case .connected: return .connected
        case .disconnected: return self == .connected ? .interrupted : self
        case .failed, .closed: return .interrupted
        }
    }
}

struct ReachHandControls {
    let canOpen: Bool
    let canTake: Bool
    let showsOutgoing: Bool
    let canWithdraw: Bool

    init(availability: ReachHomeAvailability, now: Date, phase: ReachCallPhase, roomID: String?, busy: Bool) {
        let idle = phase.showsHandCards && phase != .outgoing
        let verifiedOwnHand = idle && availability.state == .ownHand
            && availability.paired(at: now) && roomID != nil
        canOpen = idle && !busy && availability.canOpen(at: now)
        canTake = idle && !busy && roomID != nil && availability.canTake(at: now)
        showsOutgoing = phase == .outgoing || verifiedOwnHand
        canWithdraw = phase == .outgoing || (verifiedOwnHand && !busy)
    }

    static func verifiedAvailability(partnership: Partnership, pair: PairRecord, room: RoomRecord?, now: Date) -> ReachHomeAvailability {
        let availability = ReachHomeAvailability.resolve(partnership: partnership, pair: pair, room: room, now: now)
        guard availability.state == .partnerHand else { return availability }
        guard let offer = room?.offer else { return .checking }
        guard offer.type == "offer",
              (try? ReachSignalingValidation.validate(.init(kind: .offer, sdp: offer.sdp))) != nil else {
            return .unavailable
        }
        return availability
    }

    static func canWithdraw(roomID: String, partnership: Partnership, pair: PairRecord) -> Bool {
        PairSessionInterpreter.presentation(pair: pair, partnership: partnership) == .myHandOpen(roomID: roomID)
    }
}
