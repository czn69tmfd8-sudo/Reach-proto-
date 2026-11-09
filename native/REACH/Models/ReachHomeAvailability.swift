import Foundation

/// Conservative display hints only. The call controller always reauthorizes the
/// member, room and consent at the moment of an explicit tap.
struct ReachHomeAvailability: Equatable, Sendable {
    enum State: Equatable, Sendable { case checking, unpaired, invitation, ready, ownHand, partnerHand, unavailable }
    var state: State
    var verifiedUntil: Date = .distantPast

    static let checking = Self(state: .checking)
    static let unpaired = Self(state: .unpaired)
    static let invitation = Self(state: .invitation)
    static let unavailable = Self(state: .unavailable)

    func canOpen(at now: Date) -> Bool { state == .ready && verifiedUntil > now }
    func canTake(at now: Date) -> Bool { state == .partnerHand && verifiedUntil > now }
    func paired(at now: Date) -> Bool {
        [State.ready, .ownHand, .partnerHand].contains(state) && verifiedUntil > now
    }
    func title(at now: Date) -> String {
        if [State.ready, .ownHand, .partnerHand].contains(state) && verifiedUntil <= now { return "Checking availability" }
        switch state {
        case .checking: return "Checking your connection"
        case .unpaired: return "Pair to reach each other"
        case .invitation: return "Waiting for your partner to pair"
        case .ready: return "Paired · ready when you are"
        case .ownHand: return "Your hand is open"
        case .partnerHand: return "Their hand is open"
        case .unavailable: return "Connection needs attention"
        }
    }

    static func resolve(partnership: Partnership, pair: PairRecord, room: RoomRecord?, now: Date) -> Self {
        guard partnership.localMemberID != partnership.partnerMemberID,
              partnership.isAuthorized, pair.isUsable(by: partnership.localMemberID),
              pair.partnerUID(for: partnership.localMemberID) == partnership.partnerMemberID else { return .unavailable }
        let presentation = PairSessionInterpreter.presentation(pair: pair, partnership: partnership)
        if presentation == .none { return Self(state: .ready, verifiedUntil: now.addingTimeInterval(15)) }
        guard let room, room.isCurrent(at: now), room.pairCode == partnership.id,
              room.hostUid == pair.openedBy, room.answer == nil,
              Set([room.hostUid, room.partnerUid ?? ""]) == Set([partnership.localMemberID, partnership.partnerMemberID]) else { return .unavailable }
        let until = min(room.expiresAt, now.addingTimeInterval(15))
        switch presentation {
        case .myHandOpen: return Self(state: .ownHand, verifiedUntil: until)
        case .partnerHandOpen: return Self(state: .partnerHand, verifiedUntil: until)
        default: return .unavailable
        }
    }
}
