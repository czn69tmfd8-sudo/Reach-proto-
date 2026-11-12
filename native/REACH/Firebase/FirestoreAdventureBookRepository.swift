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
    private var memoryListeners: [String: ListenerRegistration] = [:]
    private var childListeners: [ListenerRegistration] = []
    private var childGeneration = 0
    private var installedScope = AdventureBookContentScope()
    private var contentScope = AdventureBookContentScope()
    private var onObservedChange: (@MainActor (Result<AdventureBook, Error>) -> Void)?
    private(set) var loadedScope = AdventureBookContentScope()
    private var observingCode: String?
    private var observationGeneration = 0
    private var refreshTask: Task<Void, Never>?
    private var refreshRequested = false
    private var dirtyMemoryIDs = Set<String>()
    private var observedBook: AdventureBook?

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
        guard try activeUID() == uid else {
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
        try await loadBook(pairCode: pairCode, scope: nil)
    }

    private func loadBook(pairCode: String, scope: AdventureBookContentScope?) async throws -> AdventureBook {
        _ = try await verifiedCode(pairCode)
        // Traverse stable document-ID pages rather than silently discarding
        // everything beyond the first fifty memories. Each request is bounded.
        var memorySnapshots: [QueryDocumentSnapshot] = []
        var lastMemory: QueryDocumentSnapshot?
        repeat {
            try Task.checkCancellation()
            var query: Query = memoriesCollection(pairCode)
                .order(by: FieldPath.documentID()).limit(to: 50)
            if let lastMemory { query = query.start(afterDocument: lastMemory) }
            let page = try await query.getDocuments(source: .server)
            memorySnapshots.append(contentsOf: page.documents)
            lastMemory = page.documents.last
            if page.documents.count < 50 { break }
            // Refuse an unexpectedly large book instead of issuing unlimited
            // reads or presenting an incomplete book as fully synchronized.
            if memorySnapshots.count >= 500 {
                guard let lastMemory else { throw AdventureBookRepositoryError.unavailable }
                let overflow = try await memoriesCollection(pairCode)
                    .order(by: FieldPath.documentID())
                    .start(afterDocument: lastMemory)
                    .limit(to: 1).getDocuments(source: .server)
                guard overflow.documents.isEmpty else {
                    throw AdventureBookRepositoryError.unavailable
                }
                break
            }
        } while true
        var memories: [AdventureMemory] = []
        for snapshot in memorySnapshots {
            try Task.checkCancellation()
            let memory = try decodeMemory(snapshot, pairCode: pairCode)
            let level = scope?.level(for: memory.id) ?? .detail
            memories.append(try await loadContent(for: memory, level: level))
        }
        // Pairing can be revoked during the multi-request load. Revalidate
        // before any assembled content is returned to the view.
        _ = try await verifiedCode(pairCode)
        return AdventureBook(pairCode: pairCode, memories: memories)
    }

    private func decodeMemory(_ snapshot: DocumentSnapshot, pairCode: String) throws -> AdventureMemory {
        let fields = snapshot.data() ?? [:]
        guard let creator = fields["creatorUid"] as? String,
              let title = fields["title"] as? String,
              let date = fields["occurredAt"] as? Timestamp,
              let order = fields["pageOrder"] as? Int else {
            throw AdventureBookRepositoryError.unavailable
        }
        return .init(id: snapshot.documentID, pairCode: pairCode, creatorUID: creator,
                     title: title, occurredAt: date.dateValue(), stories: [], photos: [],
                     comments: [], pageOrder: order)
    }

    private func loadContent(for memory: AdventureMemory, level: AdventureBookContentScope.Level) async throws -> AdventureMemory {
        var memory = memory
        memory.stories = []
        memory.comments = []
        memory.photos = []
        guard level != .summary else { return memory }

        let ref = memoriesCollection(memory.pairCode).document(memory.id)
        let photoQuery = contentQuery("photos", under: ref, level: level)
        let photoDocs = try await photoQuery.getDocuments(source: .server)
        memory.photos = try photoDocs.documents.map { item -> AdventureMemory.Photo in
            let data = item.data()
            guard let owner = data["ownerUid"] as? String,
                  let path = data["storagePath"] as? String,
                  let caption = data["caption"] as? String,
                  let position = data["position"] as? Int else {
                throw AdventureBookRepositoryError.unavailable
            }
            return .init(id: item.documentID, ownerUID: owner,
                         storagePath: path, caption: caption, position: position)
        }.sorted {
            if $0.position != $1.position { return $0.position < $1.position }
            return $0.id < $1.id
        }
        guard level == .detail else { return memory }
        let storyDocs = try await ref.collection("stories").limit(to: 2).getDocuments(source: .server)
        // Read the full supported conversation in bounded server pages.
        // A single 50-document query silently hid older comments.
        var commentSnapshots: [QueryDocumentSnapshot] = []
        var lastComment: QueryDocumentSnapshot?
        repeat {
            try Task.checkCancellation()
            var query: Query = ref.collection("comments")
                .order(by: FieldPath.documentID()).limit(to: 50)
            if let lastComment { query = query.start(afterDocument: lastComment) }
            let page = try await query.getDocuments(source: .server)
            commentSnapshots.append(contentsOf: page.documents)
            lastComment = page.documents.last
            if page.documents.count < 50 { break }
            // Never silently present a truncated conversation as complete.
            if commentSnapshots.count >= 500 {
                let overflow = try await ref.collection("comments")
                    .order(by: FieldPath.documentID())
                    .start(afterDocument: lastComment!)
                    .limit(to: 1).getDocuments(source: .server)
                guard overflow.documents.isEmpty else {
                    throw AdventureBookRepositoryError.unavailable
                }
                break
            }
        } while true
        let stories = try storyDocs.documents.map { item -> AdventureMemory.Story in
            let data = item.data()
            guard let uid = data["authorUid"] as? String,
                  let text = data["text"] as? String,
                  let time = data["updatedAt"] as? Timestamp else {
                throw AdventureBookRepositoryError.unavailable
            }
            return .init(authorUID: uid, text: text, updatedAt: time.dateValue())
        }
        let comments = try commentSnapshots.map { item -> AdventureMemory.Comment in
            let data = item.data()
            guard let uid = data["authorUid"] as? String,
                  let text = data["text"] as? String,
                  let time = data["createdAt"] as? Timestamp else {
                throw AdventureBookRepositoryError.unavailable
            }
            return .init(id: item.documentID, authorUID: uid, text: text, createdAt: time.dateValue())
        }
        memory.stories = stories.sorted { $0.authorUID < $1.authorUID }
        memory.comments = comments.sorted {
            if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
            return $0.id < $1.id
        }
        return memory
    }

    func createMemory(_ memory: AdventureMemory) async throws {
        try await createMemory(memory, initialStory: "")
    }

    func createMemory(_ memory: AdventureMemory, initialStory: String) async throws {
        let uid = try await verifiedCode(memory.pairCode)
        guard uid == memory.creatorUID,
              let path = AdventureBookPaths.memory(pairCode: memory.pairCode, memoryID: memory.id),
              !memory.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              memory.title.utf8.count <= 120, memory.pageOrder >= 0,
              memory.occurredAt.timeIntervalSince1970.isFinite,
              initialStory.utf8.count <= 6000 else {
            throw AdventureBookRepositoryError.invalidMemory
        }
        // Do not silently drop local stories or photo drafts during publication.
        guard memory.stories.isEmpty, memory.photos.isEmpty, memory.comments.isEmpty else {
            throw AdventureBookRepositoryError.invalidMemory
        }
        let ref = db.document(path)
        let occurredAt = Timestamp(date: memory.occurredAt)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            db.runTransaction({ transaction, pointer -> Any? in
            do {
                let existing = try transaction.getDocument(ref)
                if existing.exists {
                    guard let data = existing.data(),
                          data["pairCode"] as? String == memory.pairCode,
                          data["creatorUid"] as? String == uid,
                          data["title"] as? String == memory.title,
                          data["pageOrder"] as? Int == memory.pageOrder,
                          let storedDate = data["occurredAt"] as? Timestamp,
                          abs(storedDate.dateValue().timeIntervalSince(memory.occurredAt)) < 0.000_002 else {
                        throw AdventureBookRepositoryError.conflict
                    }
                    return nil
                }
                transaction.setData([
                    "pairCode": memory.pairCode,
                    "creatorUid": uid,
                    "title": memory.title,
                    "occurredAt": occurredAt,
                    "pageOrder": memory.pageOrder,
                    "createdAt": FieldValue.serverTimestamp()
                ], forDocument: ref)
            } catch {
                pointer?.pointee = error as NSError
            }
            return nil
            }, completion: { _, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: ()) }
            })
        }
        if !initialStory.isEmpty {
            // The current rules require the memory to exist before its story.
            // A retry adopts the original memory and can finish this second write.
            _ = try await verifiedCode(memory.pairCode)
            try await stories.saveOwnStory(pairCode: memory.pairCode, memoryID: memory.id, uid: uid,
                                           text: initialStory, expectedVersion: nil,
                                           acceptIdenticalCreate: true)
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
        try await postComment(pairCode: pairCode, memoryID: memoryID, text: text,
                              commentID: UUID().uuidString.lowercased())
    }

    func postComment(pairCode: String, memoryID: String, text: String, commentID: String) async throws {
        let uid = try await verifiedCode(pairCode)
        guard let base = AdventureBookPaths.memory(pairCode: pairCode, memoryID: memoryID),
              SharedContentPolicy.documentID(commentID),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              text.utf8.count <= 2000 else { throw AdventureBookRepositoryError.invalidMemory }
        let ref = db.document(base).collection("comments").document(commentID)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            db.runTransaction({ transaction, pointer -> Any? in
                do {
                    let existing = try transaction.getDocument(ref)
                    if let data = existing.data() {
                        guard data["authorUid"] as? String == uid, data["text"] as? String == text else {
                            throw AdventureBookRepositoryError.conflict
                        }
                    } else {
                        transaction.setData([
                            "authorUid": uid, "text": text, "createdAt": FieldValue.serverTimestamp()
                        ], forDocument: ref)
                    }
                } catch {
                    pointer?.pointee = error as NSError
                }
                return nil
            }, completion: { _, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: ()) }
            })
        }
    }

    /// Listener payloads are never used as authorized content. All visible
    /// updates come from fresh server reads after revalidating both member locks.
    func observe(pairCode: String, onChange: @escaping @MainActor (Result<AdventureBook, Error>) -> Void) async throws {
        stopObserving()
        let generation = observationGeneration
        _ = try await verifiedCode(pairCode)
        guard observationGeneration == generation, !Task.isCancelled else {
            throw CancellationError()
        }
        observingCode = pairCode
        onObservedChange = onChange
        installMemoryListeners(for: [], pairCode: pairCode, generation: generation, onChange: onChange)
    }

    private func installMemoryListeners(
        for memories: [AdventureMemory], pairCode: String, generation: Int,
        onChange: @escaping @MainActor (Result<AdventureBook, Error>) -> Void
    ) {
        // Each page watches from the previous page's last ID. Keep a tail
        // listener when the last page is full so a new highest ID is detected.
        let anchors = [""] + stride(from: 49, to: memories.count, by: 50).map { memories[$0].id }
        for obsolete in Set(memoryListeners.keys).subtracting(anchors) {
            memoryListeners.removeValue(forKey: obsolete)?.remove()
        }
        for anchor in anchors where memoryListeners[anchor] == nil {
            var query: Query = memoriesCollection(pairCode).order(by: FieldPath.documentID()).limit(to: 50)
            if !anchor.isEmpty { query = query.start(after: [anchor]) }
            memoryListeners[anchor] = query.addSnapshotListener(includeMetadataChanges: true) {
                [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self, self.observationGeneration == generation,
                          self.memoryListeners[anchor] != nil else { return }
                    if let error {
                        self.stopObserving()
                        onChange(.failure(error))
                        return
                    }
                    guard let snapshot, !snapshot.metadata.isFromCache,
                          !snapshot.metadata.hasPendingWrites else { return }
                    self.scheduleRefresh(pairCode: pairCode, generation: generation, onChange: onChange)
                }
            }
        }
    }

    func updateContentScope(_ scope: AdventureBookContentScope) {
        guard contentScope != scope else { return }
        let changed = contentScope.memoryIDs.union(scope.memoryIDs)
        contentScope = scope
        guard let code = observingCode, let onChange = onObservedChange else { return }
        installChildListeners(pairCode: code, generation: observationGeneration, onChange: onChange)
        for id in changed {
            scheduleRefresh(pairCode: code, generation: observationGeneration, memoryID: id, onChange: onChange)
        }
    }

    /// Root changes re-page the book. Child changes reload only their memory.
    /// Keep invalidations received during a read for the next refresh.
    private func scheduleRefresh(
        pairCode: String, generation: Int, memoryID: String? = nil,
        onChange: @escaping @MainActor (Result<AdventureBook, Error>) -> Void
    ) {
        guard observingCode == pairCode, observationGeneration == generation else { return }
        if let memoryID {
            dirtyMemoryIDs.insert(memoryID)
        } else {
            refreshRequested = true
        }
        guard refreshTask == nil else { return }
        refreshTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while self.observationGeneration == generation,
                  self.refreshRequested || !self.dirtyMemoryIDs.isEmpty {
                let reloadBook = self.refreshRequested
                let dirtyIDs = self.dirtyMemoryIDs
                let scope = self.contentScope
                self.refreshRequested = false
                self.dirtyMemoryIDs.removeAll()
                do {
                    let latest: AdventureBook
                    if !reloadBook, let previous = self.observedBook {
                        latest = try await self.refreshMemories(dirtyIDs, in: previous, scope: scope)
                    } else {
                        latest = try await self.loadBook(pairCode: pairCode, scope: scope)
                    }
                    guard self.observationGeneration == generation else { break }
                    self.installMemoryListeners(for: latest.memories, pairCode: pairCode,
                                                generation: generation, onChange: onChange)
                    guard self.contentScope == scope else {
                        self.refreshRequested = self.refreshRequested || reloadBook || self.observedBook == nil
                        self.dirtyMemoryIDs.formUnion(dirtyIDs)
                        continue
                    }
                    self.installChildListeners(pairCode: pairCode, generation: generation, onChange: onChange)
                    self.observedBook = latest
                    self.loadedScope = scope
                    onChange(.success(latest))
                } catch {
                    guard self.observationGeneration == generation else { break }
                    self.stopObserving()
                    onChange(.failure(error))
                    break
                }
            }
            if self.observationGeneration == generation {
                self.refreshTask = nil
            }
        }
    }

    private func refreshMemories(
        _ ids: Set<String>, in previous: AdventureBook, scope: AdventureBookContentScope
    ) async throws -> AdventureBook {
        let pairCode = previous.pairCode
        _ = try await verifiedCode(pairCode)
        var latest = previous
        for index in latest.memories.indices where ids.contains(latest.memories[index].id) {
            try Task.checkCancellation()
            let memory = latest.memories[index]
            latest.memories[index] = try await loadContent(for: memory, level: scope.level(for: memory.id))
        }
        _ = try await verifiedCode(pairCode)
        return latest
    }

    private func contentQuery(
        _ name: String, under memory: DocumentReference, level: AdventureBookContentScope.Level
    ) -> Query {
        let collection = memory.collection(name)
        switch name {
        case "stories":
            return collection.limit(to: 2)
        case "comments":
            return collection.order(by: "createdAt", descending: true).limit(to: 50)
        default:
            if level == .photos {
                return collection.order(by: "position").order(by: FieldPath.documentID()).limit(to: 1)
            }
            return collection.limit(to: 50)
        }
    }

    private func installChildListeners(
        pairCode: String, generation: Int,
        onChange: @escaping @MainActor (Result<AdventureBook, Error>) -> Void
    ) {
        guard installedScope != contentScope else { return }
        installedScope = contentScope
        childGeneration += 1
        let childEpoch = childGeneration
        childListeners.forEach { $0.remove() }
        childListeners.removeAll()
        for id in contentScope.memoryIDs {
            let base = memoriesCollection(pairCode).document(id)
            let level = contentScope.level(for: id)
            for name in level.collections {
                let query = contentQuery(name, under: base, level: level)
                let registration = query.addSnapshotListener(includeMetadataChanges: true) {
                    [weak self] snapshot, error in
                    Task { @MainActor [weak self] in
                        guard let self, self.observationGeneration == generation,
                              self.childGeneration == childEpoch else { return }
                        if let error {
                            self.stopObserving()
                            onChange(.failure(error))
                            return
                        }
                        // Process the initial server event as well as updates.
                        // This closes the gap between hydration and attachment.
                        guard let snapshot, !snapshot.metadata.isFromCache,
                              !snapshot.metadata.hasPendingWrites else { return }
                        self.scheduleRefresh(pairCode: pairCode, generation: generation,
                                             memoryID: id, onChange: onChange)
                    }
                }
                childListeners.append(registration)
            }
        }
    }

    func stopObserving() {
        observationGeneration += 1
        memoryListeners.values.forEach { $0.remove() }
        memoryListeners.removeAll()
        childGeneration += 1
        childListeners.forEach { $0.remove() }
        childListeners.removeAll()
        installedScope = AdventureBookContentScope()
        contentScope = AdventureBookContentScope()
        loadedScope = AdventureBookContentScope()
        onObservedChange = nil
        observingCode = nil
        refreshRequested = false
        dirtyMemoryIDs.removeAll()
        observedBook = nil
        refreshTask?.cancel()
        refreshTask = nil
    }

}
