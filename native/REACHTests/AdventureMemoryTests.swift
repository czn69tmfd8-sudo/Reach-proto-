import XCTest
@testable import REACH

final class AdventureMemoryTests: XCTestCase {
    private let first = "first-user"
    private let second = "second-user"
    private var members: Set<String> { [first, second] }

    private func memory() -> AdventureMemory {
        AdventureMemory(id: "memory-1", pairCode: "ABCDEFGHJKLM",
                        creatorUID: first, title: "Our first adventure",
                        occurredAt: Date(timeIntervalSince1970: 1_700_000_000),
                        stories: [], photos: [], comments: [], pageOrder: 0)
    }

    func testValidEmptyMemoryAndTwoIndependentStories() {
        var value = memory()
        XCTAssertTrue(value.isValid(members: members))
        XCTAssertTrue(value.updateStory(as: first, text: "My perspective", at: Date(), members: members))
        XCTAssertTrue(value.updateStory(as: second, text: "Your perspective", at: Date(), members: members))
        XCTAssertEqual(value.stories.count, 2)
        XCTAssertEqual(value.stories.first(where: { $0.authorUID == first })?.text, "My perspective")
        XCTAssertEqual(value.stories.first(where: { $0.authorUID == second })?.text, "Your perspective")
        XCTAssertTrue(value.isValid(members: members))
    }

    func testOnePartnerCannotOverwriteOtherStory() {
        var value = memory()
        XCTAssertTrue(value.updateStory(as: first, text: "Original", at: Date(), members: members))
        XCTAssertFalse(value.updateStory(as: "outsider", text: "Overwrite", at: Date(), members: members))
        XCTAssertEqual(value.stories[0].text, "Original")
    }

    func testCommentsRequireAuthorMembershipAndUniqueID() {
        var value = memory()
        let comment = AdventureMemory.Comment(id: "comment-1", authorUID: second,
                                               text: "Remember this?", createdAt: Date())
        XCTAssertFalse(value.addComment(comment, as: first, members: members))
        XCTAssertTrue(value.addComment(comment, as: second, members: members))
        XCTAssertFalse(value.addComment(comment, as: second, members: members))
        XCTAssertEqual(value.comments.count, 1)
    }

    func testRejectInvalidPhotoStoragePathAndNonMemberOwner() {
        var value = memory()
        value.photos = [.init(id: "photo-1", ownerUID: first,
                              storagePath: "https://external.example/photo.jpg",
                              caption: "", position: 0)]
        XCTAssertFalse(value.isValid(members: members))
        value.photos = [.init(id: "photo-1", ownerUID: "outsider",
                              storagePath: "adventureBook/photo-1", caption: "", position: 0)]
        XCTAssertFalse(value.isValid(members: members))
    }

    func testRejectPhotoPathThatDoesNotMatchItsPhotoID() {
        var value = memory()
        value.photos = [.init(id: "photo-1", ownerUID: first,
                              storagePath: "adventureBook/ABCDEFGHJKLM/memory-1/photo-2",
                              caption: "", position: 0)]
        XCTAssertFalse(value.isValid(members: members))
        value.photos = [.init(id: "photo-1", ownerUID: first,
                              storagePath: "adventureBook/ABCDEFGHJKLM/memory-1/photo-1",
                              caption: "", position: 0)]
        XCTAssertTrue(value.isValid(members: members))
    }

    func testRejectDuplicateStoryAuthors() {
        var value = memory()
        let now = Date()
        value.stories = [.init(authorUID: first, text: "A", updatedAt: now),
                         .init(authorUID: first, text: "B", updatedAt: now)]
        XCTAssertFalse(value.isValid(members: members))
    }

    func testCodableRoundTripPreservesBothPerspectives() throws {
        var value = memory()
        XCTAssertTrue(value.updateStory(as: first, text: "First", at: Date(), members: members))
        XCTAssertTrue(value.updateStory(as: second, text: "Second", at: Date(), members: members))
        let decoded = try JSONDecoder().decode(AdventureMemory.self, from: JSONEncoder().encode(value))
        XCTAssertEqual(decoded, value)
    }
}
