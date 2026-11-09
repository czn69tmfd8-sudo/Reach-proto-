import Foundation

/// Fresh native staging records are isolated from every existing web record.
enum ReachCollections {
    static let root = "nativeStaging/v1"
    static let pairInvites = root + "/pairInvites"
    static let memberLocks = root + "/memberLocks"
    static let rooms = root + "/rooms"
    static let hostCandidates = "hostCandidates"
    static let partnerCandidates = "partnerCandidates"
}

struct MemberLockRecord: Codable, Equatable, Sendable {
    let pairCode: String
}

struct PairRecord: Codable, Equatable, Sendable {
    let hostUid: String
    let partnerUid: String?
    var revoked: Bool?
    var activeRoom: String?
    var openedBy: String?
    var invitationExpiresAt: Date? = nil

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

struct RoomRecord: Codable, Equatable, Sendable {
    var hostUid: String
    var partnerUid: String?
    var pairCode: String
    var createdAt: Date?
    var expiresAt: Date
    var active: Bool
    var offer: SessionDescriptionRecord?
    var answer: SessionDescriptionRecord?

    func isCurrent(at now: Date = Date()) -> Bool {
        active && expiresAt > now
    }
}

struct SessionDescriptionRecord: Codable, Equatable, Sendable {
    let type: String
    let sdp: String
}

struct IceCandidateRecord: Codable, Equatable, Sendable {
    let candidate: String
    let sdpMid: String?
    let sdpMLineIndex: Int?
}
