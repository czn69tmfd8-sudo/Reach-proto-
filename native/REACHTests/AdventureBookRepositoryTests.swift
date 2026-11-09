import XCTest
@testable import REACH

final class AdventureBookRepositoryTests: XCTestCase {
    func testMemoryAndStoryPathsStayWithinPair() {
        XCTAssertEqual(
            AdventureBookPaths.memory(pairCode: "ABCDEFGHJKLM", memoryID: "summer-trip"),
            "adventureBooks/ABCDEFGHJKLM/memories/summer-trip"
        )
        XCTAssertEqual(
            AdventureBookPaths.story(pairCode: "ABCDEFGHJKLM", memoryID: "summer-trip", authorUID: "user-one"),
            "adventureBooks/ABCDEFGHJKLM/memories/summer-trip/stories/user-one"
        )
        XCTAssertEqual(
            AdventureBookPaths.comment(pairCode: "ABCDEFGHJKLM", memoryID: "summer-trip", commentID: "comment-1"),
            "adventureBooks/ABCDEFGHJKLM/memories/summer-trip/comments/comment-1"
        )
        XCTAssertEqual(
            AdventureBookPaths.photo(pairCode: "ABCDEFGHJKLM", memoryID: "summer-trip", photoID: "photo-1"),
            "adventureBook/ABCDEFGHJKLM/summer-trip/photo-1"
        )
    }

    func testRejectInvalidOrTraversalIdentifiers() {
        XCTAssertNil(AdventureBookPaths.memory(pairCode: "invalid", memoryID: "summer-trip"))
        XCTAssertNil(AdventureBookPaths.memory(pairCode: "ABCDEFGHJKLM", memoryID: "../other"))
        XCTAssertNil(AdventureBookPaths.story(pairCode: "ABCDEFGHJKLM", memoryID: "summer-trip", authorUID: "user/other"))
        XCTAssertNil(AdventureBookPaths.photo(pairCode: "ABCDEFGHJKLM", memoryID: "..", photoID: "photo-1"))
    }
}
