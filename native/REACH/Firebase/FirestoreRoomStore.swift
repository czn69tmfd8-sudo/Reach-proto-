import FirebaseFirestore
import Foundation

final class FirestoreRoomStore: ReachRoomStore {
    private let db: Firestore

    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    func createRoom(
        pairCode: String,
        openedBy uid: String,
        partnerUID: String
    ) async throws -> ReachSession {
        let roomID = UUID().uuidString
        let openedAt = Date()
        let pairRef = db.collection(ReachCollections.pairInvites).document(pairCode)
        let roomRef = db.collection(ReachCollections.rooms).document(roomID)

        try await db.runTransaction { transaction, errorPointer in
            do {
                let pairSnapshot = try transaction.getDocument(pairRef)
                guard let pairData = pairSnapshot.data(),
                      let hostUID = pairData["hostUid"] as? String else {
                    throw FirestoreRoomStoreError.pairMissing
                }

                let storedPartnerUID = pairData["partnerUid"] as? String
                let revoked = pairData["revoked"] as? Bool ?? false

                guard !revoked else {
                    throw FirestoreRoomStoreError.pairRevoked
                }

                guard uid == hostUID || uid == storedPartnerUID else {
                    throw FirestoreRoomStoreError.unauthorized
                }

                let expectedPartner = uid == hostUID ? storedPartnerUID : hostUID
                guard expectedPartner == partnerUID else {
                    throw FirestoreRoomStoreError.partnerMismatch
                }

                if let activeRoom = pairData["activeRoom"] as? String,
                   !activeRoom.isEmpty {
                    let currentOpenedBy = pairData["openedBy"] as? String

                    if currentOpenedBy == uid {
                        throw FirestoreRoomStoreError.alreadyOpen(activeRoom)
                    }

                    throw FirestoreRoomStoreError.partnerAlreadyOpen
                }

                transaction.setData([
                    "hostUid": uid,
                    "partnerUid": partnerUID,
                    "active": true,
                    "createdAt": Timestamp(date: openedAt)
                ], forDocument: roomRef)

                transaction.updateData([
                    "activeRoom": roomID,
                    "openedBy": uid
                ], forDocument: pairRef)

                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }

        return ReachSession(
            id: roomID,
            partnershipID: pairCode,
            openedBy: uid,
            openedAt: openedAt,
            phase: .open
        )
    }

    func room(id: String) async throws -> RoomRecord? {
        let snapshot = try await db.collection(ReachCollections.rooms)
            .document(id)
            .getDocument()

        guard snapshot.exists, let data = snapshot.data() else { return nil }

        return RoomRecord(
            hostUid: data["hostUid"] as? String ?? "",
            partnerUid: data["partnerUid"] as? String,
            active: data["active"] as? Bool ?? false,
            offer: Self.decodeDescription(data["offer"]),
            answer: Self.decodeDescription(data["answer"])
        )
    }

    func observeRoom(id: String) -> AsyncThrowingStream<RoomRecord?, Error> {
        AsyncThrowingStream { continuation in
            let registration = db.collection(ReachCollections.rooms)
                .document(id)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        continuation.finish(throwing: error)
                        return
                    }

                    guard let snapshot, snapshot.exists, let data = snapshot.data() else {
                        continuation.yield(nil)
                        return
                    }

                    continuation.yield(
                        RoomRecord(
                            hostUid: data["hostUid"] as? String ?? "",
                            partnerUid: data["partnerUid"] as? String,
                            active: data["active"] as? Bool ?? false,
                            offer: Self.decodeDescription(data["offer"]),
                            answer: Self.decodeDescription(data["answer"])
                        )
                    )
                }

            continuation.onTermination = { _ in registration.remove() }
        }
    }

    func clearPairSessionIfCurrent(
        pairCode: String,
        roomID: String
    ) async throws {
        let pairRef = db.collection(ReachCollections.pairInvites).document(pairCode)
        let roomRef = db.collection(ReachCollections.rooms).document(roomID)

        try await db.runTransaction { transaction, errorPointer in
            do {
                let pairSnapshot = try transaction.getDocument(pairRef)
                let currentRoom = pairSnapshot.data()?["activeRoom"] as? String

                transaction.setData(["active": false], forDocument: roomRef, merge: true)

                if currentRoom == roomID {
                    transaction.updateData([
                        "activeRoom": FieldValue.delete(),
                        "openedBy": FieldValue.delete()
                    ], forDocument: pairRef)
                }

                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
    }

    private static func decodeDescription(_ value: Any?) -> SessionDescriptionRecord? {
        guard let data = value as? [String: Any],
              let type = data["type"] as? String,
              let sdp = data["sdp"] as? String else {
            return nil
        }

        return SessionDescriptionRecord(type: type, sdp: sdp)
    }
}

enum FirestoreRoomStoreError: LocalizedError, Equatable {
    case pairMissing
    case pairRevoked
    case unauthorized
    case partnerMismatch
    case partnerAlreadyOpen
    case alreadyOpen(String)

    var errorDescription: String? {
        switch self {
        case .pairMissing:
            return "The partnership no longer exists."
        case .pairRevoked:
            return "The partnership has been revoked."
        case .unauthorized:
            return "This device is not authorized for the partnership."
        case .partnerMismatch:
            return "The expected partner does not match the partnership."
        case .partnerAlreadyOpen:
            return "Your partner already has their hand open."
        case .alreadyOpen:
            return "Your hand is already open."
        }
    }
}
