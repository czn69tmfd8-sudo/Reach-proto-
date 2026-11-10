import Foundation

/// Offline contract for a future paired, shared Adventure Book.
/// No storage, networking, or implicit sharing is performed by this model.
struct AdventureMemory: Identifiable, Equatable, Sendable, Codable {
    struct Story: Equatable, Sendable, Codable {
        let authorUID: String
        var text: String
        var updatedAt: Date
    }

    struct Photo: Identifiable, Equatable, Sendable, Codable {
        let id: String
        let ownerUID: String
        /// Storage object reference, not an unrestricted external URL.
        let storagePath: String
        var caption: String
        var position: Int
    }

    struct Comment: Identifiable, Equatable, Sendable, Codable {
        let id: String
        let authorUID: String
        let text: String
        let createdAt: Date
    }

    let id: String
    let pairCode: String
    let creatorUID: String
    var title: String
    var occurredAt: Date
    var stories: [Story]
    var photos: [Photo]
    var comments: [Comment]
    var pageOrder: Int

    /// Both partner stories are first-class contributions, never comments.
    func isValid(members: Set<String>) -> Bool {
        AdventureBookPaths.safeSegment(id)
            && SharedContentPolicy.pairCode(pairCode)
            && members.count == 2
            && members.contains(creatorUID)
            && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && title.utf8.count <= 120
            && occurredAt.timeIntervalSince1970.isFinite
            && pageOrder >= 0
            && stories.count <= 2
            && Set(stories.map(\.authorUID)).count == stories.count
            && stories.allSatisfy { members.contains($0.authorUID) && $0.text.utf8.count <= 6000 && $0.updatedAt.timeIntervalSince1970.isFinite }
            && photos.count <= 20
            && Set(photos.map(\.id)).count == photos.count
            && photos.allSatisfy {
                AdventureBookPaths.safeSegment($0.id)
                    && members.contains($0.ownerUID)
                    && $0.storagePath == AdventureBookPaths.photo(pairCode: pairCode, memoryID: id, photoID: $0.id)
                    && !$0.storagePath.contains("..")
                    && $0.caption.utf8.count <= 500
                    && $0.position >= 0
            }
            && comments.count <= 500
            && Set(comments.map(\.id)).count == comments.count
            && comments.allSatisfy {
                SharedContentPolicy.documentID($0.id)
                    && members.contains($0.authorUID)
                    && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && $0.text.utf8.count <= 2000
                    && $0.createdAt.timeIntervalSince1970.isFinite
            }
    }

    /// Only the authenticated contributor may change their own story.
    mutating func updateStory(as uid: String, text: String, at date: Date, members: Set<String>) -> Bool {
        guard members.count == 2, members.contains(uid), text.utf8.count <= 6000,
              date.timeIntervalSince1970.isFinite else { return false }
        if let index = stories.firstIndex(where: { $0.authorUID == uid }) {
            stories[index].text = text
            stories[index].updatedAt = date
        } else {
            guard stories.count < 2 else { return false }
            stories.append(Story(authorUID: uid, text: text, updatedAt: date))
        }
        return true
    }

    /// Authorization is still required at the backend; this is local validation only.
    mutating func addComment(_ comment: Comment, as uid: String, members: Set<String>) -> Bool {
        guard uid == comment.authorUID, members.count == 2, members.contains(uid),
              comments.count < 500, !comments.contains(where: { $0.id == comment.id }),
              AdventureBookPaths.safeSegment(comment.id),
              !comment.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              comment.text.utf8.count <= 2000,
              comment.createdAt.timeIntervalSince1970.isFinite else { return false }
        comments.append(comment)
        return true
    }
}
