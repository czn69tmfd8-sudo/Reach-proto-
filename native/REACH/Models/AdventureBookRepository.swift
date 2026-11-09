import Foundation

/// Proposed Firestore document layout, kept independent of Firebase SDK so
/// paths and ownership can be tested before staging rules are reviewed.
enum AdventureBookPaths {
    static func memory(pairCode: String, memoryID: String) -> String? {
        guard SharedContentPolicy.pairCode(pairCode),
              SharedContentPolicy.documentID(memoryID) else { return nil }
        return "adventureBooks/\(pairCode)/memories/\(memoryID)"
    }

    static func story(pairCode: String, memoryID: String, authorUID: String) -> String? {
        guard let base = memory(pairCode: pairCode, memoryID: memoryID),
              SharedContentPolicy.documentID(authorUID) else { return nil }
        return "\(base)/stories/\(authorUID)"
    }

    static func comment(pairCode: String, memoryID: String, commentID: String) -> String? {
        guard let base = memory(pairCode: pairCode, memoryID: memoryID),
              SharedContentPolicy.documentID(commentID) else { return nil }
        return "\(base)/comments/\(commentID)"
    }

    static func photo(pairCode: String, memoryID: String, photoID: String) -> String? {
        guard memory(pairCode: pairCode, memoryID: memoryID) != nil,
              SharedContentPolicy.documentID(photoID) else { return nil }
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
