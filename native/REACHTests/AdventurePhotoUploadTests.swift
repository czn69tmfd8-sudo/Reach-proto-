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
    func testRestartCannotBlindlyReplaceUncertainUpload() {
        var upload = AdventurePhotoUpload(pairCode: "ABCDEFGHJKLM", memoryID: "trip",
                                          photoID: "unique-photo", ownerUID: "a")
        XCTAssertTrue(upload.begin(as: "a"))
        XCTAssertFalse(upload.prepareForRecovery(as: "b"))
        XCTAssertTrue(upload.prepareForRecovery(as: "a"))
        XCTAssertEqual(upload.phase, .retryRequired)
        XCTAssertFalse(upload.begin(as: "b"))
        XCTAssertFalse(upload.metadataCommitted(as: "a"))
    }

    func testRecoveryRecordRejectsWrongOwnerHashOrLength() {
        var upload = AdventurePhotoUpload(pairCode: "ABCDEFGHJKLM", memoryID: "trip",
                                          photoID: "unique-photo", ownerUID: "a")
        XCTAssertTrue(upload.begin(as: "a"))
        XCTAssertTrue(upload.interrupted(as: "a"))
        let hash = String(repeating: "a", count: 64)
        let record = AdventurePhotoRecoveryRecord(upload: upload, sha256: hash,
                                                   byteCount: 300, caption: "", position: 0)
        XCTAssertTrue(record.canResume(as: "a", withHash: hash, byteCount: 300))
        XCTAssertFalse(record.canResume(as: "b", withHash: hash, byteCount: 300))
        XCTAssertFalse(record.canResume(as: "a", withHash: String(repeating: "b", count: 64), byteCount: 300))
        XCTAssertFalse(record.canResume(as: "a", withHash: hash, byteCount: 301))
    }

    func testJournalRoundTripAndExplicitClear() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }
        let journal = AdventurePhotoRecoveryJournal(fileURL: url)
        let upload = AdventurePhotoUpload(pairCode: "ABCDEFGHJKLM", memoryID: "trip",
                                          photoID: "unique-photo", ownerUID: "a")
        let record = AdventurePhotoRecoveryRecord(upload: upload,
            sha256: String(repeating: "0", count: 64), byteCount: 100,
            caption: "Our view", position: 2)
        try journal.save(record)
        XCTAssertEqual(try journal.load(), record)
        try journal.clear()
        XCTAssertNil(try journal.load())
    }
}
