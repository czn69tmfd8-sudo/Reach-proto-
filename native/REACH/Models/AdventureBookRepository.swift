import Foundation

/// Proposed Firestore document layout, kept independent of Firebase SDK so
/// paths and ownership can be tested before staging rules are reviewed.
enum AdventureBookPaths {
    static func safeSegment(_ value: String) -> Bool {
        SharedContentPolicy.documentID(value)
            && !value.contains("..")
            && !value.contains("%")
            && !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
    }

    static func memory(pairCode: String, memoryID: String) -> String? {
        guard SharedContentPolicy.pairCode(pairCode),
              safeSegment(memoryID) else { return nil }
        return "adventureBooks/\(pairCode)/memories/\(memoryID)"
    }

    static func story(pairCode: String, memoryID: String, authorUID: String) -> String? {
        guard let base = memory(pairCode: pairCode, memoryID: memoryID),
              safeSegment(authorUID) else { return nil }
        return "\(base)/stories/\(authorUID)"
    }

    static func comment(pairCode: String, memoryID: String, commentID: String) -> String? {
        guard let base = memory(pairCode: pairCode, memoryID: memoryID),
              safeSegment(commentID) else { return nil }
        return "\(base)/comments/\(commentID)"
    }


    /// Every story lives in its own Firestore document keyed by author UID.
    /// Updates must use an explicit server version precondition, never blind setData.
    static func ownStoryWrite(pairCode: String, memoryID: String, authorUID: String,
                              authenticatedUID: String, expectedVersion: String?) -> AdventureStoryWrite? {
        guard authenticatedUID == authorUID,
              let path = story(pairCode: pairCode, memoryID: memoryID, authorUID: authorUID),
              expectedVersion == nil || (expectedVersion?.isEmpty == false) else { return nil }
        return AdventureStoryWrite(path: path, authorUID: authorUID, expectedVersion: expectedVersion)
    }

    static func photo(pairCode: String, memoryID: String, photoID: String) -> String? {
        guard memory(pairCode: pairCode, memoryID: memoryID) != nil,
              safeSegment(photoID) else { return nil }
        return "adventureBook/\(pairCode)/\(memoryID)/\(photoID)"
    }
}

/// The view can subscribe to this interface once the staging-only backend is
/// implemented. A snapshot must be discarded immediately after pair revocation.
@MainActor
protocol AdventureBookRepository {
    func load(pairCode: String) async throws -> AdventureBook
    func createMemory(_ memory: AdventureMemory) async throws
    func saveOwnStory(pairCode: String, memoryID: String, text: String) async throws
    func postComment(pairCode: String, memoryID: String, text: String) async throws
}

enum AdventureBookRepositoryError: Error, Equatable {
    case notPaired
    case unauthorized
    case invalidMemory
    case conflict
    case unavailable
}

/// A null version is create-only; a non-null version requires the exact
/// server updateTime. Clients must reload and ask before resolving conflicts.
struct AdventureStoryWrite: Equatable, Sendable {
    let path: String
    let authorUID: String
    let expectedVersion: String?
}
