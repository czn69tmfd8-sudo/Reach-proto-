import Foundation

/// A deterministic in-memory implementation for UI integration and tests.
/// Never use this as evidence of Firebase synchronization or durable storage.
@MainActor
final class AdventureBookPreviewRepository: AdventureBookRepository {
    private(set) var book: AdventureBook
    private let memberUID: String
    private let members: Set<String>

    init(pairCode: String, memberUID: String, members: Set<String>, memories: [AdventureMemory] = []) {
        self.book = AdventureBook(pairCode: pairCode, memories: memories)
        self.memberUID = memberUID
        self.members = members
    }

    private func authorize(_ pairCode: String) throws {
        guard members.count == 2, members.contains(memberUID), book.pairCode == pairCode else {
            throw AdventureBookRepositoryError.notPaired
        }
    }

    func load(pairCode: String) async throws -> AdventureBook {
        try authorize(pairCode)
        return book
    }

    func createMemory(_ memory: AdventureMemory) async throws {
        try authorize(memory.pairCode)
        guard book.insert(memory, as: memberUID, members: members) else {
            throw AdventureBookRepositoryError.invalidMemory
        }
    }

    func saveOwnStory(pairCode: String, memoryID: String, text: String) async throws {
        try authorize(pairCode)
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              book.updateStory(memoryID: memoryID, as: memberUID, text: text, at: Date(), members: members) else {
            throw AdventureBookRepositoryError.invalidMemory
        }
    }

    func postComment(pairCode: String, memoryID: String, text: String) async throws {
        try authorize(pairCode)
        let comment = AdventureMemory.Comment(id: UUID().uuidString, authorUID: memberUID,
                                               text: text, createdAt: Date())
        guard book.addComment(memoryID: memoryID, comment: comment, as: memberUID, members: members) else {
            throw AdventureBookRepositoryError.invalidMemory
        }
    }
}
