import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation

/// Staging-only persistent Adventure Book data source. No production writes.
/// Firestore rules are authoritative; the current pair is rechecked on every
/// explicit write, and snapshots are discarded after authorization failure.
@MainActor
final class FirestoreAdventureBookRepository: AdventureBookRepository {
    private let db: Firestore
    private let stories: FirestoreAdventureStoryTransport
    private var listener: ListenerRegistration?
    private var childListeners: [ListenerRegistration] = []
    private var observingCode: String?

    init(db: Firestore = Firestore.firestore()) {
        self.db = db
        self.stories = FirestoreAdventureStoryTransport(db: db)
    }

    private func activeUID() throws -> String {
        try FirebaseBootstrap.configureStaging()
        try ReachEnvironmentGuard.validate(environment: .staging,
                                            configuredProjectID: FirebaseApp.app()?.options.projectID)
        guard let uid = Auth.auth().currentUser?.uid else {
            throw AdventureBookRepositoryError.unauthorized
        }
        return uid
    }

    private func verifiedCode(_ code: String) async throws -> String {
        let uid = try activeUID()
        guard SharedContentPolicy.pairCode(code),
              SharedContentPolicy.documentID(uid) else { throw AdventureBookRepositoryError.unauthorized }
        let lock = try await db.document("nativeStaging/v1/memberLocks/\(uid)").getDocument(source: .server)
        guard lock.data()?["pairCode"] as? String == code else {
            throw AdventureBookRepositoryError.notPaired
        }
        let pair = try await db.document("nativeStaging/v1/pairInvites/\(code)").getDocument(source: .server)
        guard pair.data()?["revoked"] as? Bool != true,
              let host = pair.data()?["hostUid"] as? String,
              let partner = pair.data()?["partnerUid"] as? String,
              [host, partner].contains(uid), host != partner else {
            throw AdventureBookRepositoryError.unauthorized
        }
        let other = uid == host ? partner : host
        let otherLock = try await db.document("nativeStaging/v1/memberLocks/\(other)").getDocument(source: .server)
        guard otherLock.data()?["pairCode"] as? String == code else {
            throw AdventureBookRepositoryError.unauthorized
        }
        return uid
    }

    private func memoriesCollection(_ code: String) -> CollectionReference {
        db.collection("adventureBooks").document(code).collection("memories")
    }

    /// Always starts from the server. Offline mode never treats a cached pair
    /// snapshot as authorization to read or edit private shared content.
    func load(pairCode: String) async throws -> AdventureBook {
        _ = try await verifiedCode(pairCode)
        let snapshots = try await memoriesCollection(pairCode).limit(to: 50).getDocuments(source: .server)
        var memories: [AdventureMemory] = []
        for snapshot in snapshots.documents {
            let fields = snapshot.data()
            guard let creator = fields["creatorUid"] as? String,
                  let title = fields["title"] as? String,
                  let date = fields["occurredAt"] as? Timestamp,
                  let order = fields["pageOrder"] as? Int else {
                throw AdventureBookRepositoryError.unavailable
            }
            let ref = snapshot.reference
            let storyDocs = try await ref.collection("stories").limit(to: 2).getDocuments(source: .server)
            let commentDocs = try await ref.collection("comments").limit(to: 50).getDocuments(source: .server)
            let photoDocs = try await ref.collection("photos").limit(to: 50).getDocuments(source: .server)
            let stories = try storyDocs.documents.map { item -> AdventureMemory.Story in
                let data = item.data()
                guard let uid = data["authorUid"] as? String,
                      let text = data["text"] as? String,
                      let time = data["updatedAt"] as? Timestamp else {
                    throw AdventureBookRepositoryError.unavailable
                }
                return .init(authorUID: uid, text: text, updatedAt: time.dateValue())
            }
            let comments = try commentDocs.documents.map { item -> AdventureMemory.Comment in
                let data = item.data()
                guard let uid = data["authorUid"] as? String,
                      let text = data["text"] as? String,
                      let time = data["createdAt"] as? Timestamp else {
                    throw AdventureBookRepositoryError.unavailable
                }
                return .init(id: item.documentID, authorUID: uid, text: text, createdAt: time.dateValue())
            }
            let photos = try photoDocs.documents.map { item -> AdventureMemory.Photo in
                let data = item.data()
                guard let owner = data["ownerUid"] as? String,
                      let path = data["storagePath"] as? String,
                      let caption = data["caption"] as? String,
                      let position = data["position"] as? Int else {
                    throw AdventureBookRepositoryError.unavailable
                }
                return .init(id: item.documentID, ownerUID: owner,
                             storagePath: path, caption: caption, position: position)
            }
            memories.append(.init(id: snapshot.documentID, pairCode: pairCode,
                                  creatorUID: creator, title: title, occurredAt: date.dateValue(),
                                  stories: stories, photos: photos, comments: comments, pageOrder: order))
        }
        // Pairing can be revoked during the multi-request load. Revalidate
        // before any assembled content is returned to the view.
        _ = try await verifiedCode(pairCode)
        return AdventureBook(pairCode: pairCode, memories: memories)
    }

    func createMemory(_ memory: AdventureMemory) async throws {
        let uid = try await verifiedCode(memory.pairCode)
        guard uid == memory.creatorUID,
              let path = AdventureBookPaths.memory(pairCode: memory.pairCode, memoryID: memory.id),
              !memory.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              memory.title.utf8.count <= 120, memory.pageOrder >= 0 else {
            throw AdventureBookRepositoryError.invalidMemory
        }
        // Do not silently drop local stories or photo drafts during publication.
        guard memory.stories.isEmpty, memory.photos.isEmpty, memory.comments.isEmpty else {
            throw AdventureBookRepositoryError.invalidMemory
        }
        let ref = db.document(path)
        _ = try await db.runTransaction { transaction, pointer -> Any? in
            do {
                let existing = try transaction.getDocument(ref)
                guard !existing.exists else { throw AdventureBookRepositoryError.conflict }
                transaction.setData([
                    "pairCode": memory.pairCode,
                    "creatorUid": uid,
                    "title": memory.title,
                    "occurredAt": Timestamp(date: memory.occurredAt),
                    "pageOrder": memory.pageOrder,
                    "createdAt": FieldValue.serverTimestamp()
                ], forDocument: ref)
            } catch {
                pointer?.pointee = error as NSError
            }
            return nil
        }
    }

    func saveOwnStory(pairCode: String, memoryID: String, text: String) async throws {
        // An editor must provide the version of the story it actually displayed.
        // Fetching a fresh version here would allow a stale draft to overwrite
        // an unseen edit. Refuse this legacy unversioned API instead.
        throw AdventureBookRepositoryError.conflict
    }

    /// Explicit versioned write for editors that retain a server snapshot.
    func saveOwnStory(pairCode: String, memoryID: String, text: String,
                      expectedVersion: Timestamp?) async throws {
        let uid = try await verifiedCode(pairCode)
        try await stories.saveOwnStory(pairCode: pairCode, memoryID: memoryID, uid: uid,
                                       text: text, expectedVersion: expectedVersion)
    }

    func postComment(pairCode: String, memoryID: String, text: String) async throws {
        let uid = try await verifiedCode(pairCode)
        guard let base = AdventureBookPaths.memory(pairCode: pairCode, memoryID: memoryID),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              text.utf8.count <= 2000 else { throw AdventureBookRepositoryError.invalidMemory }
        try await db.document(base).collection("comments").document(UUID().uuidString.lowercased())
            .setData(["authorUid": uid, "text": text, "createdAt": FieldValue.serverTimestamp()])
    }

    /// Listener invalidation triggers a fresh server-backed, authorization-
    /// checked load. Never expose unverified cached listener payloads.
    func observe(pairCode: String, onChange: @escaping @MainActor (Result<AdventureBook, Error>) -> Void) async throws {
        _ = try await verifiedCode(pairCode)
        stopObserving()
        observingCode = pairCode
        listener = memoriesCollection(pairCode).limit(to: 50).addSnapshotListener { [weak self] _, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let error {
                    self.stopObserving()
                    onChange(.failure(error))
                    return
                }
                guard self.observingCode == pairCode else { return }
                do {
                    let book = try await self.load(pairCode: pairCode)
                    guard self.observingCode == pairCode else { return }
                    self.installChildListeners(for: book, pairCode: pairCode, onChange: onChange)
                    onChange(.success(book))
                }
                catch {
                    self.listener?.remove()
                    self.listener = nil
                    onChange(.failure(error))
                }
            }
        }
    }

    private func installChildListeners(
        for book: AdventureBook, pairCode: String,
        onChange: @escaping @MainActor (Result<AdventureBook, Error>) -> Void
    ) {
        childListeners.forEach { $0.remove() }
        childListeners = []
        guard observingCode == pairCode else { return }
        for memory in book.memories {
            let base = memoriesCollection(pairCode).document(memory.id)
            for name in ["stories", "comments", "photos"] {
                let registration = base.collection(name).limit(to: 50).addSnapshotListener {
                    [weak self] snapshot, error in
                    Task { @MainActor [weak self] in
                        guard let self, self.observingCode == pairCode else { return }
                        if let error {
                            self.stopObserving()
                            onChange(.failure(error))
                            return
                        }
                        guard snapshot?.metadata.isFromCache == false else { return }
                        do {
                            let refreshed = try await self.load(pairCode: pairCode)
                            guard self.observingCode == pairCode else { return }
                            onChange(.success(refreshed))
                        }
                        catch {
                            self.stopObserving()
                            onChange(.failure(error))
                        }
                    }
                }
                childListeners.append(registration)
            }
        }
    }

    func stopObserving() {
        listener?.remove()
        listener = nil
        childListeners.forEach { $0.remove() }
        childListeners = []
        observingCode = nil
    }
}
