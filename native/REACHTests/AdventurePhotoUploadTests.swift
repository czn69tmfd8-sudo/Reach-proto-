import XCTest
@testable import REACH

final class AdventurePhotoUploadTests: XCTestCase {
    func testInterruptedUploadNeverBecomesPublishedWithoutMetadata() {
        var upload = AdventurePhotoUpload(pairCode: "ABCDEFGHJKLM", memoryID: "trip",
                                          photoID: "unique-photo", ownerUID: "a")
        XCTAssertEqual(upload.objectPath, "adventureBook/ABCDEFGHJKLM/trip/unique-photo")
        XCTAssertTrue(upload.begin(as: "a"))
        XCTAssertTrue(upload.interrupted(as: "a"))
        XCTAssertFalse(upload.metadataCommitted(as: "a"))
        XCTAssertTrue(upload.begin(as: "a"))
        XCTAssertTrue(upload.uploaded(as: "a"))
        XCTAssertFalse(upload.begin(as: "a"))
        XCTAssertTrue(upload.metadataCommitted(as: "a"))
        XCTAssertEqual(upload.phase, .published)
    }

    func testPartnerCannotAdvanceAnotherPersonsUpload() {
        var upload = AdventurePhotoUpload(pairCode: "ABCDEFGHJKLM", memoryID: "trip",
                                          photoID: "unique-photo", ownerUID: "a")
        XCTAssertFalse(upload.begin(as: "b"))
        XCTAssertTrue(upload.begin(as: "a"))
        XCTAssertFalse(upload.uploaded(as: "b"))
        XCTAssertFalse(upload.interrupted(as: "b"))
    }
}
