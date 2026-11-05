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

        // A session is absent only when both pointer fields are absent.
        // Half-written or blank pointers must never authorize a new room.
        if pair.activeRoom == nil && pair.openedBy == nil {
            return .none
        }

        guard let roomID = pair.activeRoom,
              !roomID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let openedBy = pair.openedBy,
              !openedBy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .invalid
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
