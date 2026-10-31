import FirebaseFirestore
import Foundation

final class FirestorePairStore: ReachPairStore {
    private let db: Firestore

    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    func memberLock(uid: String) async throws -> MemberLockRecord? {
        let snapshot = try await db.collection(ReachCollections.memberLocks)
            .document(uid)
            .getDocument()

        guard snapshot.exists, let data = snapshot.data() else { return nil }
        guard let pairCode = data["pairCode"] as? String, !pairCode.isEmpty else {
            return nil
        }

        return MemberLockRecord(pairCode: pairCode)
    }

    func pair(code: String) async throws -> PairRecord? {
        let snapshot = try await db.collection(ReachCollections.pairInvites)
            .document(code)
            .getDocument()

        guard snapshot.exists, let data = snapshot.data() else { return nil }
        return Self.decodePair(data)
    }

    func observePair(code: String) -> AsyncThrowingStream<PairRecord?, Error> {
        AsyncThrowingStream { continuation in
            let registration = db.collection(ReachCollections.pairInvites)
                .document(code)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        continuation.finish(throwing: error)
                        return
                    }

                    guard let snapshot, snapshot.exists, let data = snapshot.data() else {
                        continuation.yield(nil)
                        return
                    }

                    continuation.yield(Self.decodePair(data))
                }

            continuation.onTermination = { _ in
                registration.remove()
            }
        }
    }

    private static func decodePair(_ data: [String: Any]) -> PairRecord? {
        guard let hostUid = data["hostUid"] as? String else { return nil }

        return PairRecord(
            hostUid: hostUid,
            partnerUid: data["partnerUid"] as? String,
            revoked: data["revoked"] as? Bool ?? false,
            activeRoom: data["activeRoom"] as? String,
            openedBy: data["openedBy"] as? String
        )
    }
}
