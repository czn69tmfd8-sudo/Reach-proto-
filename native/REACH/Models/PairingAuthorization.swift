import Foundation

enum PairingAuthorizationResult: Equatable {
    case authorized(Partnership)
    case noMemberLock
    case pairMissing
    case pairRevoked
    case pairIncomplete
    case memberMismatch
}

enum PairingAuthorization {
    static func resolve(
        uid: String,
        memberLock: MemberLockRecord?,
        pairCode: String?,
        pair: PairRecord?
    ) -> PairingAuthorizationResult {
        guard let memberLock else { return .noMemberLock }
        guard memberLock.pairCode == pairCode, let pair else { return .pairMissing }
        guard pair.revoked != true else { return .pairRevoked }
        guard pair.contains(uid: uid) else { return .memberMismatch }
        guard let partnerUID = pair.partnerUID(for: uid) else { return .pairIncomplete }

        return .authorized(
            Partnership(
                id: memberLock.pairCode,
                localMemberID: uid,
                partnerMemberID: partnerUID,
                partnerDisplayName: "Partner",
                isAuthorized: true
            )
        )
    }
}
