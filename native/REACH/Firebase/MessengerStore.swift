import FirebaseAuth
import FirebaseFirestore
import SwiftUI

@MainActor
final class MessengerStore: ObservableObject {
    struct Message: Identifiable {
        let id: String
        let sender: String
        let text: String
        let timestamp: Timestamp

        init?(_ document: QueryDocumentSnapshot) {
            let data = document.data()
            guard let sender = data["senderUid"] as? String,
                  let text = data["text"] as? String,
                  let timestamp = data["createdAt"] as? Timestamp else { return nil }
            id = document.documentID
            self.sender = sender
            self.text = text
            self.timestamp = timestamp
        }
    }

    private struct Pending {
        let id: String
        let text: String
    }

    @Published private(set) var messages: [Message] = []
    @Published private(set) var notice = "Checking your pairing…"
    @Published private(set) var ownUID: String?
    @Published private(set) var unread: Set<String> = []
    @Published private(set) var hasMore = false
    @Published private(set) var sending = false
    @Published private(set) var pendingText: String?
    @Published private(set) var retryAvailable = false
    @Published private(set) var online = false
    @Published private(set) var loadingMore = false

    private var epoch = UUID()
    private var collection: CollectionReference?
    private var receipt: DocumentReference?
    private var listener: (any ListenerRegistration)?
    private var head: [QueryDocumentSnapshot] = []
    private var older: [QueryDocumentSnapshot] = []
    private var readAt: Timestamp?
    private var pending: Pending?
    private let pageSize = 30

    func watch() async {
        stop()
        let token = epoch
        do {
            try FirebaseBootstrap.configureStaging()
            let auth = Auth.auth()
            guard let uid = auth.currentUser?.uid else {
                notice = "Sign in and pair to open your messages."
                return
            }
            let (events, continuation) = AsyncStream<String?>.makeStream()
            let handle = auth.addStateDidChangeListener { _, user in
                _ = continuation.yield(user?.uid)
            }
            defer {
                auth.removeStateDidChangeListener(handle)
                continuation.finish()
            }

            let store = FirestorePairStore()
            guard let lock = try await store.memberLock(uid: uid),
                  let pair = try await store.pair(code: lock.pairCode),
                  case .authorized = PairingAuthorization.resolve(uid: uid, memberLock: lock, pairCode: lock.pairCode, pair: pair) else {
                if token == epoch && !Task.isCancelled {
                    notice = "Pair with your partner to open your messages."
                }
                return
            }

            let root = Firestore.firestore().collection("messenger").document(lock.pairCode)
            let messages = root.collection("messages")
            let receipt = root.collection("readReceipts").document(uid)
            let saved = try await receipt.getDocument(source: .server)
            guard token == epoch, !Task.isCancelled, auth.currentUser?.uid == uid else { return }
            self.collection = messages
            self.receipt = receipt
            readAt = saved.data()?["createdAt"] as? Timestamp

            listener = sorted(messages).limit(to: pageSize).addSnapshotListener(includeMetadataChanges: true) {
                [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self, self.epoch == token, Auth.auth().currentUser?.uid == uid else { return }
                    if error != nil {
                        self.stop()
                        self.notice = "This conversation is unavailable. Recheck your pairing and connection."
                        return
                    }
                    guard let snapshot else { return }
                    if snapshot.metadata.isFromCache {
                        self.online = false
                        self.notice = self.ownUID == nil ? "Waiting to verify access…" : "Offline. New messages will sync when connected."
                        return
                    }
                    self.ownUID = uid
                    self.online = true
                    self.notice = ""
                    let confirmed = snapshot.documents.filter { !$0.metadata.hasPendingWrites }
                    self.replaceHead(confirmed)
                }
            }

            let verify = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    do {
                        try await Task.sleep(for: .seconds(5))
                        // A server-only receipt read rechecks both locks even if message documents are unchanged.
                        let saved = try await receipt.getDocument(source: .server)
                        guard let self, self.epoch == token else { return }
                        self.mergeReadTime(saved.data()?["createdAt"] as? Timestamp)
                    } catch is CancellationError {
                        return
                    } catch {
                        guard let self, self.epoch == token else { return }
                        if (error as NSError).code == FirestoreErrorCode.permissionDenied.rawValue {
                            self.stop()
                            self.notice = "Access to this conversation has ended."
                            return
                        }
                    }
                }
            }
            defer { verify.cancel() }
            for await current in events {
                guard current == uid, !Task.isCancelled else { break }
            }
            if token == epoch { stop() }
        } catch {
            if token == epoch {
                stop()
                notice = "Couldn’t verify your conversation. Check your connection and try again."
            }
        }
    }

    func stop() {
        epoch = UUID()
        listener?.remove()
        listener = nil
        collection = nil
        receipt = nil
        messages = []
        ownUID = nil
        unread = []
        hasMore = false
        sending = false
        pendingText = nil
        retryAvailable = false
        online = false
        loadingMore = false
        head = []
        older = []
        readAt = nil
        pending = nil
        notice = "Checking your pairing…"
    }

    private func sorted(_ collection: CollectionReference) -> Query {
        collection.order(by: "createdAt", descending: true)
            .order(by: FieldPath.documentID(), descending: true)
    }

    private func replaceHead(_ next: [QueryDocumentSnapshot]) {
        let previousIDs = Set(head.map(\.documentID))
        if let anchor = next.last, previousIDs.contains(anchor.documentID) {
            let tail = head.drop(while: { $0.documentID != anchor.documentID }).dropFirst()
            older.insert(contentsOf: tail, at: 0)
        } else {
            older = []
            hasMore = next.count == pageSize
        }
        let ids = Set(next.map(\.documentID))
        older.removeAll { ids.contains($0.documentID) }
        head = next
        publish()
    }

    private func publish() {
        var seen = Set<String>()
        messages = (head + older).reversed().compactMap {
            guard seen.insert($0.documentID).inserted else { return nil }
            return Message($0)
        }
        unread = Set(messages.filter {
            $0.sender != ownUID && isLater($0.timestamp, than: readAt)
        }.map(\.id))
    }

    private func isLater(_ value: Timestamp, than cutoff: Timestamp?) -> Bool {
        guard let cutoff else { return true }
        return value.seconds > cutoff.seconds
            || (value.seconds == cutoff.seconds && value.nanoseconds > cutoff.nanoseconds)
    }

    private func mergeReadTime(_ value: Timestamp?) {
        guard let value, isLater(value, than: readAt) else { return }
        readAt = value
        publish()
    }

    func loadMore() async {
        guard !loadingMore, hasMore, online, let collection,
              let cursor = older.last ?? head.last else { return }
        let token = epoch
        loadingMore = true
        defer { if token == epoch { loadingMore = false } }
        do {
            let page = try await sorted(collection).start(afterDocument: cursor)
                .limit(to: pageSize).getDocuments(source: .server)
            guard token == epoch, (older.last ?? head.last)?.documentID == cursor.documentID else { return }
            older.append(contentsOf: page.documents)
            hasMore = page.count == pageSize
            publish()
        } catch {
            if token == epoch { notice = "Couldn’t load earlier messages." }
        }
    }

    func send(_ text: String) async {
        guard pending == nil, !text.isEmpty, text.utf8.count <= 4000, ownUID != nil else { return }
        pending = Pending(id: UUID().uuidString.lowercased(), text: text)
        pendingText = text
        await sendPending()
    }

    func sendPending() async {
        guard !sending, let pending, let collection, let uid = ownUID else { return }
        let token = epoch
        let ref = collection.document(pending.id)
        sending = true
        retryAvailable = false
        defer { if token == epoch { sending = false } }
        do {
            try await ref.setData([
                "senderUid": uid, "kind": "text", "text": pending.text,
                "createdAt": FieldValue.serverTimestamp()
            ])
        } catch {
            guard token == epoch else { return }
            let existing = try? await ref.getDocument(source: .server)
            guard token == epoch else { return }
            guard existing?.data()?["senderUid"] as? String == uid,
                  existing?.data()?["text"] as? String == pending.text else {
                retryAvailable = true
                notice = "Message could not be sent."
                return
            }
        }
        guard token == epoch else { return }
        self.pending = nil
        pendingText = nil
    }

    func markRead() async {
        guard online, let receipt, let last = messages.last, !unread.isEmpty else { return }
        let token = epoch
        do {
            try await receipt.setData(["messageID": last.id, "createdAt": last.timestamp])
            guard token == epoch else { return }
            mergeReadTime(last.timestamp)
        } catch {
            if token == epoch { notice = "Couldn’t update read status." }
        }
    }
}
