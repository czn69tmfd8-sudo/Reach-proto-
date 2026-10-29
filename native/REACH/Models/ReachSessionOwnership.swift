import Foundation

enum ReachSessionOwnership: Equatable {
    case mine
    case partners
    case unknown

    static func resolve(session: ReachSession?, partnership: Partnership?) -> ReachSessionOwnership {
        guard let session, let partnership else { return .unknown }
        if session.openedBy == partnership.localMemberID { return .mine }
        if session.openedBy == partnership.partnerMemberID { return .partners }
        return .unknown
    }
}
