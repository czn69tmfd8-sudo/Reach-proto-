import XCTest
@testable import REACH

final class AdventureBookTests: XCTestCase {
    private let pair = "ABCDEFGHJKLM"
    private let members: Set<String> = ["author-a", "author-b"]

    private func memory(_ id: String, order: Int, creator: String = "author-a") -> AdventureMemory {
        AdventureMemory(id: id, pairCode: pair, creatorUID: creator,
                        title: id, occurredAt: Date(timeIntervalSince1970: 1_700_000_000),
                        stories: [], photos: [], comments: [], pageOrder: order)
    }

    func testOrderingAndExplicitReorder() {
        var book = AdventureBook(pairCode: pair, memories: [memory("later", order: 2), memory("earlier", order: 0)])
        XCTAssertEqual(book.orderedMemories.map(\.id), ["earlier", "later"])
        XCTAssertTrue(book.reorder(["later", "earlier"], as: "author-b", members: members))
        XCTAssertEqual(book.orderedMemories.map(\.id), ["later", "earlier"])
        XCTAssertFalse(book.reorder(["earlier", "earlier"], as: "author-b", members: members))
    }

    func testChronologicalPagesAfterLateAddAndDateEdit() {
        func datedMemory(_ day: Int, id: String, order: Int) -> AdventureMemory {
            AdventureMemory(id: id, pairCode: pair, creatorUID: "author-a", title: id,
                            occurredAt: Date(timeIntervalSince1970: Double(day) * 86400),
                            stories: [], photos: [], comments: [], pageOrder: order)
        }
        var records = (1...8).reversed().map { datedMemory($0, id: "day-\($0)", order: 9 - $0) }
        records.append(datedMemory(0, id: "late-added", order: 9))
        let sorted = AdventureBook(pairCode: pair, memories: records).orderedMemories.map(\.id)
        XCTAssertEqual(sorted, ["late-added"] + (1...8).map { "day-\($0)" })
        XCTAssertEqual(AdventureGalleryPagination.page(forSelectedMemoryID: "day-8", orderedIDs: sorted), 3)
        records[0] = datedMemory(0, id: "day-8", order: 1)
        let edited = AdventureBook(pairCode: pair, memories: records).orderedMemories.map(\.id)
        XCTAssertEqual(Array(edited.prefix(2)), ["day-8", "late-added"])
        XCTAssertEqual(Set(edited), Set(sorted))
        XCTAssertEqual(AdventureBook(pairCode: pair, memories: Array(records.reversed())).orderedMemories.map(\.id), edited)
    }

    func testRejectOutsiderAndDuplicateMemory() {
        var book = AdventureBook(pairCode: pair, memories: [])
        XCTAssertFalse(book.insert(memory("one", order: 0), as: "outsider", members: members))
        XCTAssertTrue(book.insert(memory("one", order: 0), as: "author-a", members: members))
        XCTAssertFalse(book.insert(memory("one", order: 1), as: "author-a", members: members))
        XCTAssertEqual(book.memories.count, 1)
    }

    func testPartnerCanAddOwnStoryWithoutChangingFirst() {
        var book = AdventureBook(pairCode: pair, memories: [memory("one", order: 0)])
        XCTAssertTrue(book.updateStory(memoryID: "one", as: "author-a", text: "A", at: Date(), members: members))
        XCTAssertTrue(book.updateStory(memoryID: "one", as: "author-b", text: "B", at: Date(), members: members))
        XCTAssertFalse(book.updateStory(memoryID: "one", as: "outsider", text: "C", at: Date(), members: members))
        XCTAssertEqual(book.memories[0].stories.count, 2)
        XCTAssertEqual(book.memories[0].stories.first(where: { $0.authorUID == "author-a" })?.text, "A")
        XCTAssertEqual(book.memories[0].stories.first(where: { $0.authorUID == "author-b" })?.text, "B")
    }

    func testRejectCrossPairMemory() {
        var book = AdventureBook(pairCode: pair, memories: [])
        var foreign = memory("foreign", order: 0)
        foreign = AdventureMemory(id: foreign.id, pairCode: "JKLMNPQRSTUV", creatorUID: foreign.creatorUID,
                                  title: foreign.title, occurredAt: foreign.occurredAt,
                                  stories: [], photos: [], comments: [], pageOrder: 0)
        XCTAssertFalse(book.insert(foreign, as: "author-a", members: members))
    }

    func testBookRoundTripPreservesOrderingAndContributions() throws {
        var book = AdventureBook(pairCode: pair, memories: [memory("one", order: 0)])
        XCTAssertTrue(book.updateStory(memoryID: "one", as: "author-a", text: "My memory", at: Date(), members: members))
        let decoded = try JSONDecoder().decode(AdventureBook.self, from: JSONEncoder().encode(book))
        XCTAssertEqual(book, decoded)
        XCTAssertTrue(decoded.isValid(members: members))
    }
}
