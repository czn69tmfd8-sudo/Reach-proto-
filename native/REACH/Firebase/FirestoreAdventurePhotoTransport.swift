import CryptoKit
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import FirebaseStorage
import Foundation

/// Private staging-only photo transport. No download URLs are generated.
/// Storage objects are immutable; publication occurs only after upload success.
@MainActor
final class FirestoreAdventurePhotoTransport {
    private let storage: Storage
    private let db: Firestore

    init(storage: Storage = Storage.storage(), db: Firestore = Firestore.firestore()) {
        self.storage = storage
        self.db = db
    }

    private func verify(_ upload: AdventurePhotoUpload) throws -> String {
        try FirebaseBootstrap.configureStaging()
        try ReachEnvironmentGuard.validate(environment: .staging,
                                            configuredProjectID: FirebaseApp.app()?.options.projectID)
        guard Auth.auth().currentUser?.uid == upload.ownerUID,
              let path = upload.objectPath else {
            throw AdventureBookRepositoryError.unauthorized
        }
        return path
    }

    /// Reconnect after an interrupted upload must inspect remote metadata.
    /// A preexisting object is never replaced. If its ownership cannot be
    /// confirmed, fail closed and require an explicit recovery decision.
    func uploadJPEG(_ bytes: Data, upload: inout AdventurePhotoUpload) async throws {
        let path = try verify(upload)
        guard !bytes.isEmpty, bytes.count <= 15_728_640,
              bytes.starts(with: [0xff, 0xd8, 0xff]) else {
            throw AdventureBookRepositoryError.invalidMemory
        }
        let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        let object = storage.reference(withPath: path)
        if upload.phase == .retryRequired {
            // A missing object and a denied/timeout metadata read are distinct.
            // Never infer absence from an arbitrary Storage SDK exception.
            let remote: StorageMetadata
            do {
                remote = try await object.getMetadata()
            } catch {
                // Even objectNotFound cannot authorize a blind replacement:
                // rules remain authoritative and immutable object IDs must
                // never be silently reused after uncertain prior uploads.
                throw AdventureBookRepositoryError.unavailable
            }
            guard remote.customMetadata?["ownerUid"] == upload.ownerUID,
                  remote.size == Int64(bytes.count),
                  remote.contentType == "image/jpeg",
                  remote.customMetadata?["sha256"] == digest,
                  remote.name == upload.photoID,
                  remote.bucket == object.bucket else {
                throw AdventureBookRepositoryError.conflict
            }
            // Custom metadata is client supplied. Verify the actual remote
            // bytes, not merely the asserted hash, before recovering.
            let remoteBytes = try await object.getData(maxSize: 15_728_640)
            guard remoteBytes.count == bytes.count,
                  SHA256.hash(data: remoteBytes) == SHA256.hash(data: bytes) else {
                throw AdventureBookRepositoryError.conflict
            }
            guard upload.begin(as: upload.ownerUID),
                  upload.uploaded(as: upload.ownerUID) else {
                throw AdventureBookRepositoryError.conflict
            }
            return
        }
        guard upload.begin(as: upload.ownerUID) else {
            throw AdventureBookRepositoryError.conflict
        }
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.customMetadata = ["ownerUid": upload.ownerUID, "sha256": digest]
        do {
            _ = try await object.putDataAsync(bytes, metadata: metadata)
            guard upload.uploaded(as: upload.ownerUID) else {
                throw AdventureBookRepositoryError.conflict
            }
        } catch {
            _ = upload.interrupted(as: upload.ownerUID)
            throw error
        }
    }

    /// The metadata document is published after the object exists. Rules
    /// enforce owner identity and exact object path. Repeated publication
    /// must not silently overwrite a previous record.
    func publish(_ upload: inout AdventurePhotoUpload,
                 caption: String, position: Int) async throws {
        let path = try verify(upload)
        guard upload.phase == .uploadedAwaitingMetadata,
              caption.utf8.count <= 500, position >= 0,
              let memoryPath = AdventureBookPaths.memory(pairCode: upload.pairCode,
                                                         memoryID: upload.memoryID) else {
            throw AdventureBookRepositoryError.invalidMemory
        }
        let ownerUID = upload.ownerUID
        let ref = db.document(memoryPath).collection("photos").document(upload.photoID)
        // If the Firestore commit succeeded before a crash, recover only
        // the exact same published metadata. Do not issue a duplicate write.
        let existing = try await ref.getDocument(source: .server)
        if existing.exists {
            guard existing.data()?["ownerUid"] as? String == ownerUID,
                  existing.data()?["storagePath"] as? String == path,
                  existing.data()?["caption"] as? String == caption,
                  existing.data()?["position"] as? Int == position else {
                throw AdventureBookRepositoryError.conflict
            }
            guard upload.metadataCommitted(as: ownerUID) else {
                throw AdventureBookRepositoryError.conflict
            }
            return
        }
        _ = try await db.runTransaction { transaction, pointer -> Any? in
            do {
                let current = try transaction.getDocument(ref)
                guard !current.exists else { throw AdventureBookRepositoryError.conflict }
                transaction.setData([
                    "ownerUid": ownerUID, "storagePath": path,
                    "caption": caption, "position": position,
                    "createdAt": FieldValue.serverTimestamp()
                ], forDocument: ref)
            } catch {
                pointer?.pointee = error as NSError
            }
            return nil
        }
        guard upload.metadataCommitted(as: upload.ownerUID) else {
            throw AdventureBookRepositoryError.conflict
        }
    }

    /// Authenticated SDK byte read, not a bearer-style download URL.
    func readPhoto(pairCode: String, memoryID: String, photoID: String,
                   maximumBytes: Int64 = 15_728_640) async throws -> Data {
        try FirebaseBootstrap.configureStaging()
        try ReachEnvironmentGuard.validate(environment: .staging,
                                            configuredProjectID: FirebaseApp.app()?.options.projectID)
        guard Auth.auth().currentUser != nil,
              let path = AdventureBookPaths.photo(pairCode: pairCode,
                                                   memoryID: memoryID, photoID: photoID) else {
            throw AdventureBookRepositoryError.unauthorized
        }
        return try await storage.reference(withPath: path).getData(maxSize: maximumBytes)
    }
}
