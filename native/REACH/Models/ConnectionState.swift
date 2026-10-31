import Foundation

struct ConnectionState: Equatable {
    var partnership: Partnership?
    var session: ReachSession?
    var mediaPermission: MediaPermissionState = .unknown

    var canOpenHand: Bool {
        partnership?.isAuthorized == true && mediaPermission == .granted && session == nil
    }

    var canTakeHand: Bool {
        guard let session, let partnership else { return false }
        return partnership.isAuthorized && session.openedBy != partnership.localMemberID
    }
}

struct Partnership: Equatable, Identifiable {
    let id: String
    let localMemberID: String
    let partnerMemberID: String
    var partnerDisplayName: String
    var isAuthorized: Bool
}

struct ReachSession: Equatable, Identifiable {
    let id: String
    let partnershipID: String
    let openedBy: String
    let openedAt: Date
    var phase: ReachSessionPhase
}

enum ReachSessionPhase: Equatable {
    case open
    case connecting
    case live
    case recovering
    case ended
    case failed(String)
}

enum MediaPermissionState: Equatable {
    case unknown, requesting, granted, denied
}
