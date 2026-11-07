import FirebaseAuth
import FirebaseFirestore
import Foundation

// Firebase owns listener synchronization; this box only transfers the registration
// to AsyncThrowingStream's @Sendable termination callback for removal.
private struct PairListenerRegistrationBox: @unchecked Sendable {
    let registration: any ListenerRegistration
}

// Immutable SDK handle; Firebase synchronizes its own operations and callbacks.
final class FirestorePairStore: @unchecked Sendable, ReachPairStore {
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
        guard let uid = Auth.auth(app: db.app).currentUser?.uid else { throw InvitationError.unauthenticated }
        guard code.utf8.count == 12,
              code.allSatisfy({ "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".contains($0) }) else { throw InvitationError.unavailable }
        let db = self.db
        let lockRef = db.collection(ReachCollections.memberLocks).document(uid)
        let pairRef = db.collection(ReachCollections.pairInvites).document(code)
        let result = try await db.runTransaction { transaction, errorPointer in
            do {
                let lock = try transaction.getDocument(lockRef)
                if action != .revoke, lock.exists {
                    guard let oldCode = lock.data()?["pairCode"] as? String else { throw InvitationError.alreadyLocked }
                    let old = try transaction.getDocument(db.collection(ReachCollections.pairInvites).document(oldCode))
                    guard let oldData = old.data(),
                          NativePairingPolicy.canReplaceLock(uid: uid, lock: MemberLockRecord(pairCode: oldCode), previousPair: Self.decodePair(oldData)) else {
                        throw InvitationError.alreadyLocked
                    }
                }
                switch action {
                case .create:
                    guard try !transaction.getDocument(pairRef).exists else { throw InvitationError.unavailable }
                    transaction.setData([
                        "hostUid": uid, "partnerUid": NSNull(), "activeRoom": NSNull(), "openedBy": NSNull(),
                        "createdAt": FieldValue.serverTimestamp(),
                        "expiresAt": Int64(Date().addingTimeInterval(NativePairingPolicy.invitationLifetime).timeIntervalSince1970 * 1000)
                    ], forDocument: pairRef)
                case .accept:
                    let snapshot = try transaction.getDocument(pairRef)
                    guard let data = snapshot.data(), let invitation = Self.decodePair(data),
                          NativePairingPolicy.canAccept(uid: uid, invitation: invitation) else { throw InvitationError.unavailable }
                    transaction.updateData(["partnerUid": uid], forDocument: pairRef)
                case .revoke:
                    let snapshot = try transaction.getDocument(pairRef)
                    guard lock.data()?["pairCode"] as? String == code, let data = snapshot.data(),
                          data["hostUid"] as? String == uid || data["partnerUid"] as? String == uid else { throw InvitationError.unavailable }
                    if data["revoked"] as? Bool == true { return nil }
                    // A missing/expired/inaccessible room must never block revocation.
                    // The pair flag and cleared pointer immediately deny all signaling.
                    transaction.updateData([
                        "revoked": true, "revokedBy": uid, "revokedAt": FieldValue.serverTimestamp(),
                        "activeRoom": NSNull(), "openedBy": NSNull()
                    ], forDocument: pairRef)
                    return data["activeRoom"] as? String
                }
                transaction.setData(["pairCode": code, "createdAt": FieldValue.serverTimestamp()], forDocument: lockRef)
                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
        if action == .revoke, let roomID = result as? String {
            // Best-effort housekeeping after authorization has been irreversibly revoked.
            // Rules reject mismatched pairCode; updateData cannot create a missing room.
            // An unstructured task keeps optional cleanup independent of the UI
            // caller's cancellation; immutable pairCode and rules bound its scope.
            Task {
                try? await db.collection(ReachCollections.rooms).document(roomID).updateData([
                    "pairCode": code, "active": false, "endedAt": FieldValue.serverTimestamp()
                ])
            }
            // Do not make the revocation UI wait for optional cleanup to reconnect.
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
            .getDocument(source: .server)

        guard snapshot.exists, let data = snapshot.data() else { return nil }
        guard let pairCode = data["pairCode"] as? String, !pairCode.isEmpty else {
            return nil
        }

        return MemberLockRecord(pairCode: pairCode)
    }

    func pair(code: String) async throws -> PairRecord? {
        let snapshot = try await db.collection(ReachCollections.pairInvites)
            .document(code)
            .getDocument(source: .server)

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

            let listenerBox = PairListenerRegistrationBox(registration: registration)
            continuation.onTermination = { _ in
                listenerBox.registration.remove()
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
            openedBy: data["openedBy"] as? String,
            invitationExpiresAt: (data["expiresAt"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue / 1000) }
        )
    }
}
