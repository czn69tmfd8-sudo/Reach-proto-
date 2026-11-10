import FirebaseAuth
import FirebaseFirestore
import Foundation

/// Staging-only Adventure Book story transport. Not connected to the UI until
/// emulator rules and native simulator validation are complete.
@MainActor
final class FirestoreAdventureStoryTransport {
    private let db: Firestore

    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    struct VersionedStory {
        let text: String
        let version: Timestamp
    }

    private func document(pairCode: String, memoryID: String, uid: String) throws -> DocumentReference {
        try ReachEnvironmentGuard.validate(environment: .staging, configuredProjectID: db.app.options.projectID)
        guard let user = Auth.auth(app: db.app).currentUser, user.uid == uid,
              let path = AdventureBookPaths.story(pairCode: pairCode, memoryID: memoryID, authorUID: uid)
        else { throw AdventureBookRepositoryError.unauthorized }
        return db.document(path)
    }

    /// Force a server read: offline cached data is never an edit authorization/version.
    func loadOwnStory(pairCode: String, memoryID: String, uid: String) async throws -> VersionedStory? {
        let ref = try document(pairCode: pairCode, memoryID: memoryID, uid: uid)
        let snap = try await ref.getDocument(source: .server)
        guard snap.exists else { return nil }
        guard snap.data()?["authorUid"] as? String == uid,
              let text = snap.data()?["text"] as? String,
              let version = snap.data()?["updatedAt"] as? Timestamp
        else { throw AdventureBookRepositoryError.unavailable }
        return VersionedStory(text: text, version: version)
    }

    /// The expected timestamp comes from a previous server snapshot.
    /// Firestore retries transactions if another editor commits first; the
    /// retried read then detects the stale timestamp and refuses to overwrite.
    func saveOwnStory(pairCode: String, memoryID: String, uid: String,
                      text: String, expectedVersion: Timestamp?) async throws {
        guard text.utf8.count <= 6000 else { throw AdventureBookRepositoryError.invalidMemory }
        let ref = try document(pairCode: pairCode, memoryID: memoryID, uid: uid)
        let result = try await db.runTransaction { transaction, errorPointer -> Any? in
            do {
                let current = try transaction.getDocument(ref)
                if let expectedVersion {
                    guard current.exists,
                          current.data()?["authorUid"] as? String == uid,
                          let currentVersion = current.data()?["updatedAt"] as? Timestamp,
                          currentVersion == expectedVersion
                    else { throw AdventureBookRepositoryError.conflict }
                    transaction.updateData(["text": text, "updatedAt": FieldValue.serverTimestamp()], forDocument: ref)
                } else {
                    guard !current.exists else { throw AdventureBookRepositoryError.conflict }
                    transaction.setData([
                        "authorUid": uid,
                        "text": text,
                        "updatedAt": FieldValue.serverTimestamp()
                    ], forDocument: ref)
                }
                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
        _ = result
    }
}
