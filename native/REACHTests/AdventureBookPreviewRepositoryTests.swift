import XCTest
@testable import REACH

@MainActor
final class AdventureBookPreviewRepositoryTests: XCTestCase {
    private let pair = "ABCDEFGHJKLM"
    private let members: Set<String> = ["person-a", "person-b"]

    private func memory(_ id: String = "memory-1") -> AdventureMemory {
        AdventureMemory(id: id, pairCode: pair, creatorUID: "person-a",
                        title: "A weekend away", occurredAt: Date(timeIntervalSince1970: 1_700_000_000),
                        stories: [], photos: [], comments: [], pageOrder: 0)
    }

    func testAuthorCreatesPageAndAddsStoryAndComment() async throws {
        let repository = AdventureBookPreviewRepository(pairCode: pair, memberUID: "person-a", members: members)
        try await repository.createMemory(memory())
        try await repository.saveOwnStory(pairCode: pair, memoryID: "memory-1", text: "My favourite memory")
        try await repository.postComment(pairCode: pair, memoryID: "memory-1", text: "What a day!")
        let book = try await repository.load(pairCode: pair)
        XCTAssertEqual(book.memories.count, 1)
        XCTAssertEqual(book.memories[0].stories[0].authorUID, "person-a")
        XCTAssertEqual(book.memories[0].stories[0].text, "My favourite memory")
        XCTAssertEqual(book.memories[0].comments.count, 1)
    }

    func testOutsiderCannotReadOrWrite() async {
        let repository = AdventureBookPreviewRepository(pairCode: pair, memberUID: "outsider", members: members)
        do {
            _ = try await repository.load(pairCode: pair)
            XCTFail("Outsider must not load the book")
        } catch {
            XCTAssertEqual(error as? AdventureBookRepositoryError, .notPaired)
        }
        do {
            try await repository.createMemory(memory())
            XCTFail("Outsider must not create a memory")
        } catch {
            XCTAssertEqual(error as? AdventureBookRepositoryError, .notPaired)
        }
    }

    func testWrongPairAndEmptyStoryRejected() async throws {
        let repository = AdventureBookPreviewRepository(pairCode: pair, memberUID: "person-a", members: members)
        try await repository.createMemory(memory())
        do {
            try await repository.saveOwnStory(pairCode: "JKLMNPQRSTUV", memoryID: "memory-1", text: "wrong pair")
            XCTFail("Cross-pair edit must be rejected")
        } catch {
            XCTAssertEqual(error as? AdventureBookRepositoryError, .notPaired)
        }
        do {
            try await repository.saveOwnStory(pairCode: pair, memoryID: "memory-1", text: "  ")
            XCTFail("Blank story must be rejected")
        } catch {
            XCTAssertEqual(error as? AdventureBookRepositoryError, .invalidMemory)
        }
    }
    func testRevocationClearsLocalSnapshotAndDeniesFutureReads() async throws {
        let repository = AdventureBookPreviewRepository(pairCode: pair, memberUID: "person-a", members: members)
        try await repository.createMemory(memory())
        XCTAssertEqual((try await repository.load(pairCode: pair)).memories.count, 1)
        repository.revokePreviewAccess()
        XCTAssertTrue(repository.book.memories.isEmpty)
        do {
            _ = try await repository.load(pairCode: pair)
            XCTFail("Revoked access must fail")
        } catch {
            XCTAssertEqual(error as? AdventureBookRepositoryError, .notPaired)
        }
    }

}
