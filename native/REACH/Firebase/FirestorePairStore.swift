import FirebaseAuth
import FirebaseFirestore
import Foundation

final class FirestorePairStore: ReachPairStore {
    private let db: Firestore

    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    func createInvitation() async throws -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        let code = String((0..<12).compactMap { _ in alphabet.randomElement() })
        try await changeInvitation(code: code, action: .create)
        return code
    }

    func acceptInvitation(code: String) async throws {
        try await changeInvitation(code: code, action: .accept)
    }

    func revokeInvitation(code: String) async throws {
        try await changeInvitation(code: code, action: .revoke)
    }

    private enum InvitationAction: Sendable {
        case create, accept, revoke
    }

    private func changeInvitation(code: String, action: InvitationAction) async throws {
        try ReachEnvironmentGuard.validate(environment: .staging, configuredProjectID: db.app.options.projectID)
        guard let uid = Auth.auth(app: db.app).currentUser?.uid else {
            throw InvitationError.unauthenticated
        }
        guard code.utf8.count == 12,
              code.allSatisfy({ "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".contains($0) }) else {
            throw InvitationError.unavailable
        }

        let lockRef = db.collection(ReachCollections.memberLocks).document(uid)
        let pairRef = db.collection(ReachCollections.pairInvites).document(code)
        _ = try await db.runTransaction { transaction, errorPointer in
            do {
                let lock = try transaction.getDocument(lockRef)
                switch action {
                case .create:
                    guard !lock.exists else { throw InvitationError.alreadyLocked }
                    transaction.setData([
                        "hostUid": uid, "partnerUid": NSNull(), "activeRoom": NSNull(),
                        "openedBy": NSNull(), "createdAt": FieldValue.serverTimestamp()
                    ], forDocument: pairRef)
                case .accept:
                    guard !lock.exists else { throw InvitationError.alreadyLocked }
                    let snapshot = try transaction.getDocument(pairRef)
                    guard let data = snapshot.data(), let host = data["hostUid"] as? String,
                          host != uid, data["partnerUid"] is NSNull,
                          data["revoked"] as? Bool != true else {
                        throw InvitationError.unavailable
                    }
                    transaction.updateData(["partnerUid": uid], forDocument: pairRef)
                case .revoke:
                    let snapshot = try transaction.getDocument(pairRef)
                    guard lock.data()?["pairCode"] as? String == code,
                          let data = snapshot.data(),
                          data["hostUid"] as? String == uid || data["partnerUid"] as? String == uid else {
                        throw InvitationError.unavailable
                    }
                    transaction.updateData(["revoked": true], forDocument: pairRef)
                    return nil
                }
                transaction.setData([
                    "pairCode": code, "createdAt": FieldValue.serverTimestamp()
                ], forDocument: lockRef)
                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
    }

    private enum InvitationError: LocalizedError {
        case unauthenticated, alreadyLocked, unavailable

        var errorDescription: String? {
            switch self {
            case .unauthenticated: return "Sign in to staging first."
            case .alreadyLocked: return "This installation already has a partnership lock."
            case .unavailable: return "This pairing invitation is unavailable."
            }
        }
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
