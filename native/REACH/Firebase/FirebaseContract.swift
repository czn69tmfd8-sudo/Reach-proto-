import Foundation

/// Native representation of the proven web Firestore contract.
/// No live writes are enabled by this file.
enum ReachCollections {
    static let pairInvites = "pairInvites"
    static let memberLocks = "memberLocks"
    static let rooms = "rooms"
    static let hostCandidates = "hostCandidates"
    static let partnerCandidates = "partnerCandidates"
}

struct MemberLockRecord: Codable, Equatable {
    let pairCode: String
}

struct PairRecord: Codable, Equatable {
    let hostUid: String
    let partnerUid: String?
    var revoked: Bool?
    var activeRoom: String?
    var openedBy: String?

    func contains(uid: String) -> Bool {
        hostUid == uid || partnerUid == uid
    }

    func partnerUID(for uid: String) -> String? {
        hostUid == uid ? partnerUid : hostUid
    }

    func isUsable(by uid: String) -> Bool {
        revoked != true && contains(uid: uid) && partnerUID(for: uid) != nil
    }
}

struct RoomRecord: Codable, Equatable {
    var hostUid: String
    var partnerUid: String?
    var active: Bool
    var offer: SessionDescriptionRecord?
    var answer: SessionDescriptionRecord?
}

struct SessionDescriptionRecord: Codable, Equatable {
    let type: String
    let sdp: String
}

struct IceCandidateRecord: Codable, Equatable {
    let candidate: String
    let sdpMid: String?
    let sdpMLineIndex: Int?
}
