import XCTest
@testable import REACH

final class AdventureGalleryPaginationTests: XCTestCase {
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

    func testLargeGalleryDoesNotOverflowRange() {
        XCTAssertEqual(AdventureGalleryPagination.memoryRange(spread: 124, memoryCount: 1000), 992..<1000)
        XCTAssertEqual(AdventureGalleryPagination.spreadCount(memoryCount: 1000), 125)
    }
}
