import XCTest
@testable import REACH

final class AdventureGalleryPaginationTests: XCTestCase {
    func testLiveScopeBoundsNestedListenersAcrossFiveHundredMemories() {
        let ids = (0..<500).map(String.init)
        let cover = AdventureBookContentScope(orderedIDs: ids)
        XCTAssertTrue(cover.memoryIDs.isEmpty)

        let spread = AdventureBookContentScope(orderedIDs: ids, page: 62)
        XCTAssertEqual(spread.memoryIDs, Set(ids[488..<496]))
        XCTAssertEqual(spread.memoryIDs.flatMap { spread.level(for: $0).collections }, Array(repeating: "photos", count: 8))
        XCTAssertEqual(spread.level(for: ids[487]), .summary)

        let open = AdventureBookContentScope(orderedIDs: ids, page: 62, openedMemoryID: ids[489])
        XCTAssertEqual(open.memoryIDs, [ids[489]])
        XCTAssertEqual(open.level(for: ids[489]).collections, ["stories", "comments", "photos"])
        XCTAssertEqual(open.level(for: ids[490]), .summary)

        let missing = AdventureBookContentScope(orderedIDs: ids, page: 63, openedMemoryID: "missing")
        XCTAssertNil(missing.detailID)
        XCTAssertEqual(missing.memoryIDs, Set(ids[496..<500]))
    }

    func testEmptyBookHasOneGallerySpread() {
        XCTAssertEqual(AdventureGalleryPagination.spreadCount(memoryCount: 0), 1)
        XCTAssertTrue(AdventureGalleryPagination.memoryRange(spread: 0, memoryCount: 0).isEmpty)
        XCTAssertEqual(AdventureGalleryPagination.clampedPage(99, memoryCount: 0), 1)
    }

    func testEightSlotsAndAutomaticAdditionalSpreads() {
        for (count, expected) in [(1, 1), (7, 1), (8, 1), (9, 2), (16, 2), (17, 3), (80, 10)] {
            XCTAssertEqual(AdventureGalleryPagination.spreadCount(memoryCount: count), expected)
            let flattened = (0..<expected).flatMap {
                Array(AdventureGalleryPagination.memoryRange(spread: $0, memoryCount: count))
            }
            XCTAssertEqual(flattened, Array(0..<count))
        }
    }

    func testGalleryPageRestorationAndBounds() {
        XCTAssertEqual(AdventureGalleryPagination.spread(forMemoryAt: 0), 1)
        XCTAssertEqual(AdventureGalleryPagination.spread(forMemoryAt: 7), 1)
        XCTAssertEqual(AdventureGalleryPagination.spread(forMemoryAt: 8), 2)
        XCTAssertNil(AdventureGalleryPagination.spread(forMemoryAt: -1))
        XCTAssertEqual(AdventureGalleryPagination.clampedPage(2, memoryCount: 10), 2)
        XCTAssertEqual(AdventureGalleryPagination.clampedPage(2, memoryCount: 3), 1)
        XCTAssertEqual(AdventureGalleryPagination.clampedPage(-3, memoryCount: 3), 0)
        XCTAssertTrue(AdventureGalleryPagination.memoryRange(spread: 3, memoryCount: 8).isEmpty)
    }

    func testSelectedMemoryUsesStableIdentityAfterReorderingOrRemoval() {
        XCTAssertEqual(AdventureGalleryPagination.selectedMemoryID("b", availableIDs: ["c", "b", "a"]), "b")
        XCTAssertNil(AdventureGalleryPagination.selectedMemoryID("b", availableIDs: ["c", "a"]))
        XCTAssertNil(AdventureGalleryPagination.selectedMemoryID(nil, availableIDs: ["a"]))
    }

    func testExtremeCountsDoNotOverflow() {
        XCTAssertEqual(AdventureGalleryPagination.spreadCount(memoryCount: Int.max),
                       Int.max / 8 + 1)
        XCTAssertEqual(AdventureGalleryPagination.clampedPage(Int.max, memoryCount: 1), 1)
        XCTAssertTrue(AdventureGalleryPagination.memoryRange(spread: Int.max, memoryCount: 1).isEmpty)
        XCTAssertEqual(AdventureGalleryPagination.spreadCount(memoryCount: -5), 1)
    }

    func testMemoryRestorationAfterRemoteReorder() {
        let initial = (0..<17).map { "memory-\($0)" }
        XCTAssertEqual(AdventureGalleryPagination.page(forSelectedMemoryID: "memory-8", orderedIDs: initial), 2)
        let reordered = ["memory-8"] + initial.filter { $0 != "memory-8" }
        XCTAssertEqual(AdventureGalleryPagination.page(forSelectedMemoryID: "memory-8", orderedIDs: reordered), 1)
        XCTAssertNil(AdventureGalleryPagination.page(forSelectedMemoryID: "deleted", orderedIDs: reordered))
    }

    func testAppendOrderPreservesGapsAndRejectsSaturation() {
        XCTAssertEqual(AdventureGalleryPagination.nextPageOrder(existing: []), 0)
        XCTAssertEqual(AdventureGalleryPagination.nextPageOrder(existing: [0, 2, 7]), 8)
        XCTAssertEqual(AdventureGalleryPagination.nextPageOrder(existing: [9, 1, 3]), 10)
        XCTAssertNil(AdventureGalleryPagination.nextPageOrder(existing: [Int.max]))
        XCTAssertNil(AdventureGalleryPagination.nextPageOrder(existing: [-1]))
    }

    func testMemoryAppendRequiresCompleteSnapshot() {
        XCTAssertTrue(AdventureGalleryPagination.canAppendMemory(loadedCount: 0))
        XCTAssertTrue(AdventureGalleryPagination.canAppendMemory(loadedCount: 49))
        XCTAssertFalse(AdventureGalleryPagination.canAppendMemory(loadedCount: 50))
        XCTAssertFalse(AdventureGalleryPagination.canAppendMemory(loadedCount: 51))
        XCTAssertFalse(AdventureGalleryPagination.canAppendMemory(loadedCount: -1))
        XCTAssertFalse(AdventureGalleryPagination.canAppendMemory(loadedCount: 0, queryLimit: 0))
    }

    func testExpandedServerSnapshotAllowsSafeAppendPastFifty() {
        XCTAssertTrue(AdventureGalleryPagination.canAppendMemory(loadedCount: 50, queryLimit: 500))
        XCTAssertTrue(AdventureGalleryPagination.canAppendMemory(loadedCount: 499, queryLimit: 500))
        XCTAssertFalse(AdventureGalleryPagination.canAppendMemory(loadedCount: 500, queryLimit: 500))
        XCTAssertEqual(AdventureGalleryPagination.spreadCount(memoryCount: 500), 63)
        XCTAssertEqual(AdventureGalleryPagination.memoryRange(spread: 62, memoryCount: 500), 496..<500)
    }

    func testLargeGalleryDoesNotOverflowRange() {
        XCTAssertEqual(AdventureGalleryPagination.memoryRange(spread: 124, memoryCount: 1000), 992..<1000)
        XCTAssertEqual(AdventureGalleryPagination.spreadCount(memoryCount: 1000), 125)
    }

    func testTwoPhoneSharedMemoryConvergesAfterServerSnapshots() {
        let members: Set<String> = ["byron", "aaron"]
        let pairCode = "ABCDEFGHJKLM"
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let memory = AdventureMemory(id: "lake-weekend", pairCode: pairCode,
                                     creatorUID: "byron", title: "The Lake Weekend",
                                     occurredAt: date, stories: [], photos: [],
                                     comments: [], pageOrder: 0)
        var server = AdventureBook(pairCode: pairCode, memories: [])
        var byronPhone = server
        var aaronPhone = server

        XCTAssertTrue(server.insert(memory, as: "byron", members: members))
        byronPhone = server
        aaronPhone = server // Aaron receives the next authorized server snapshot.
        XCTAssertEqual(byronPhone, aaronPhone)

        XCTAssertTrue(server.updateStory(memoryID: memory.id, as: "aaron",
                                         text: "My side of the weekend", at: date,
                                         members: members))
        aaronPhone = server
        byronPhone = server // Byron receives the next authorized server snapshot.
        XCTAssertEqual(byronPhone.memories[0].stories.first?.authorUID, "aaron")
        XCTAssertEqual(byronPhone, aaronPhone)

        let comment = AdventureMemory.Comment(id: "comment-one", authorUID: "byron",
                                               text: "Let's go again", createdAt: date)
        XCTAssertTrue(server.addComment(memoryID: memory.id, comment: comment,
                                        as: "byron", members: members))
        byronPhone = server
        aaronPhone = server
        XCTAssertEqual(aaronPhone.memories[0].comments.first?.text, "Let's go again")
        XCTAssertEqual(byronPhone, aaronPhone)
    }

    func testPartnerCannotOverwriteOtherPartnersStoryOrPostAsThem() {
        let members: Set<String> = ["byron", "aaron"]
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        var memory = AdventureMemory(id: "lake-weekend", pairCode: "ABCDEFGHJKLM",
                                     creatorUID: "byron", title: "The Lake Weekend",
                                     occurredAt: date, stories: [], photos: [],
                                     comments: [], pageOrder: 0)
        XCTAssertTrue(memory.updateStory(as: "aaron", text: "Aaron's story",
                                         at: date, members: members))
        XCTAssertFalse(memory.updateStory(as: "stranger", text: "Unauthorized",
                                          at: date, members: members))
        XCTAssertEqual(memory.stories.count, 1)
        XCTAssertEqual(memory.stories[0].text, "Aaron's story")
        let forged = AdventureMemory.Comment(id: "forged-comment", authorUID: "aaron",
                                              text: "Forged", createdAt: date)
        XCTAssertFalse(memory.addComment(forged, as: "byron", members: members))
    }
}
