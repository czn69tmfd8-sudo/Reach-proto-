import Foundation

/// Native representation of the currently proven web Firestore contract.
/// This file contains collection/field names only. It intentionally contains
/// no production credentials and performs no writes.
enum ReachFirestoreContract {
    enum Collection {
        static let pairInvites = "pairInvites"
        static let memberLocks = "memberLocks"
        static let rooms = "rooms"
        static let hostCandidates = "hostCandidates"
        static let partnerCandidates = "partnerCandidates"
    }

    enum PairField {
        static let hostUID = "hostUid"
        static let partnerUID = "partnerUid"
        static let revoked = "revoked"
        static let activeRoom = "activeRoom"
        static let openedBy = "openedBy"
        static let profilePhotos = "profilePhotos"
        static let dailyQuestionAnswers = "dailyQuestionAnswers"
    }

    enum LockField {
        static let pairCode = "pairCode"
    }

    enum RoomField {
        static let hostUID = "hostUid"
        static let partnerUID = "partnerUid"
        static let pairCode = "pairCode"
        static let createdAt = "createdAt"
        static let expiresAt = "expiresAt"
        static let active = "active"
        static let offer = "offer"
        static let answer = "answer"
        static let endedAt = "endedAt"
    }

    static let webSessionLifetime: TimeInterval = 8 * 60 * 60
}
