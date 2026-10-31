import Foundation

enum PairSessionPresentation: Equatable {
    case none
    case myHandOpen(roomID: String)
    case partnerHandOpen(roomID: String)
    case invalid
}

enum PairSessionInterpreter {
    static func presentation(
        pair: PairRecord,
        partnership: Partnership
    ) -> PairSessionPresentation {
        guard partnership.isAuthorized else { return .invalid }
        guard pair.contains(uid: partnership.localMemberID) else { return .invalid }
        guard pair.revoked != true else { return .invalid }

        guard
            let roomID = pair.activeRoom,
            !roomID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            let openedBy = pair.openedBy
        else {
            return .none
        }

        if openedBy == partnership.localMemberID {
            return .myHandOpen(roomID: roomID)
        }

        if openedBy == partnership.partnerMemberID {
            return .partnerHandOpen(roomID: roomID)
        }

        return .invalid
    }
}
