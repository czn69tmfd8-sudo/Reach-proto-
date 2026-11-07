import Foundation

/// Native re-pairing retains the authenticated UID and historical pair documents.
/// Only a member of the revoked prior pair may move their own native lock.
enum NativePairingPolicy {
    static let invitationLifetime: TimeInterval = 30 * 60

    static func canReplaceLock(uid: String, lock: MemberLockRecord?, previousPair: PairRecord?) -> Bool {
        guard lock != nil else { return true }
        guard let previousPair else { return false }
        return previousPair.revoked == true && previousPair.contains(uid: uid)
    }

    static func canAccept(uid: String, invitation: PairRecord, now: Date = Date()) -> Bool {
        invitation.hostUid != uid && invitation.partnerUid == nil && invitation.revoked != true
            && (invitation.invitationExpiresAt.map { $0 > now } ?? false)
    }
}
