import Foundation

protocol ReachAuthenticationProvider {
    func currentUID() async -> String?
    func signInAnonymously() async throws -> String
}

protocol ReachPairStore {
    func memberLock(uid: String) async throws -> MemberLockRecord?
    func pair(code: String) async throws -> PairRecord?
    func observePair(code: String) -> AsyncThrowingStream<PairRecord?, Error>
}

protocol ReachRoomStore {
    func createRoom(
        pairCode: String,
        openedBy uid: String,
        partnerUID: String
    ) async throws -> ReachSession

    func room(id: String) async throws -> RoomRecord?
    func observeRoom(id: String) -> AsyncThrowingStream<RoomRecord?, Error>

    func clearPairSessionIfCurrent(
        pairCode: String,
        roomID: String
    ) async throws
}

struct FirebaseReachDependencies {
    let auth: any ReachAuthenticationProvider
    let pairs: any ReachPairStore
    let rooms: any ReachRoomStore
}
