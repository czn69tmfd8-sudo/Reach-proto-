import Foundation

struct PairResolver {
    let auth: any ReachAuthenticationProvider
    let pairs: any ReachPairStore

    func resolveCurrentPartnership() async throws -> PairingAuthorizationResult {
        let uid: String
        if let existing = await auth.currentUID() {
            uid = existing
        } else {
            uid = try await auth.signInAnonymously()
        }

        guard let lock = try await pairs.memberLock(uid: uid) else {
            return .noMemberLock
        }

        let pair = try await pairs.pair(code: lock.pairCode)

        return PairingAuthorization.resolve(
            uid: uid,
            memberLock: lock,
            pairCode: lock.pairCode,
            pair: pair
        )
    }
}
