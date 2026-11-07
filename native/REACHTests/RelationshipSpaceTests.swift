import XCTest
@testable import REACH

final class RelationshipSpaceTests: XCTestCase {
    private let scope = RelationshipScope(uid: "a", pairCode: "ABCDEFGHJKLM")

    func testPrivateJournalUpgradesWithoutSharingOrChangingPhoto() throws {
        let privateEntry = RelationshipEntry(kind: .memory, title: "Private memory",
            body: "Private caption", photo: Data([1, 2, 3]))
        var journal = RelationshipJournal()
        try journal.save(privateEntry)
        let encoded = try JSONEncoder().encode(journal)
        let reopened = try JSONDecoder().decode(RelationshipJournal.self, from: encoded)
        XCTAssertEqual(reopened.version, 1)
        XCTAssertEqual(reopened.entries, [privateEntry])

        let reviewedCopy = SharedRelationshipEntry.memoryCopy(of: privateEntry, photo: Data([4, 5, 6]))
        XCTAssertNotEqual(reviewedCopy.id, privateEntry.id)
        XCTAssertEqual(reviewedCopy.caption, privateEntry.body)
        XCTAssertEqual(reviewedCopy.photo, Data([4, 5, 6]))
        XCTAssertEqual(reopened.entries.first?.photo, Data([1, 2, 3]))
    }

    func testScopeFailsClosedForRevocationMalformedPairAndNonMember() {
        var pair = PairRecord(hostUid: "a", partnerUid: "b", revoked: false, activeRoom: nil, openedBy: nil)
        XCTAssertEqual(RelationshipScope.resolve(uid: "a", code: scope.pairCode, pair: pair), scope)
        XCTAssertNil(RelationshipScope.resolve(uid: "c", code: scope.pairCode, pair: pair))
        XCTAssertNil(RelationshipScope.resolve(uid: "a", code: "../bad", pair: pair))
        XCTAssertNil(RelationshipScope.resolve(uid: "a", code: scope.pairCode, pair: nil))
        pair.revoked = true
        XCTAssertNil(RelationshipScope.resolve(uid: "a", code: scope.pairCode, pair: pair))
    }

    func testNewWriteRequiresAbsenceAndEditRequiresReviewedVersion() throws {
        let entry = SharedRelationshipEntry(kind: .goal, title: "Take a trip", progress: 40)
        let create = SharedRelationshipConsent(scope: scope, entry: entry, previous: nil)
        let encodedCreate = try JSONEncoder().encode(create.precondition)
        XCTAssertEqual(String(decoding: encodedCreate, as: UTF8.self), #"{"exists":false}"#)
        try create.validate(for: scope)

        let record = SharedRelationshipRecord(entry: entry, scope: scope, authorUID: "a", version: "reviewed")
        let edit = SharedRelationshipConsent(scope: scope, entry: entry, previous: record)
        let encodedEdit = try JSONEncoder().encode(edit.precondition)
        XCTAssertEqual(String(decoding: encodedEdit, as: UTF8.self), #"{"updateTime":"reviewed"}"#)
        try edit.validate(for: scope)
        for differentScope in [
            RelationshipScope(uid: "b", pairCode: scope.pairCode),
            RelationshipScope(uid: "a", pairCode: "NPQRSTUVWXYZ")
        ] {
            XCTAssertThrowsError(try edit.validate(for: differentScope))
            XCTAssertFalse(record.isOwned(by: differentScope))
        }
        let partnerRecord = SharedRelationshipRecord(entry: entry, scope: scope, authorUID: "b", version: "reviewed")
        XCTAssertThrowsError(try SharedRelationshipConsent(scope: scope, entry: entry, previous: partnerRecord).validate(for: scope))
        let newEntry = SharedRelationshipEntry(kind: .goal, title: "Different entry")
        XCTAssertThrowsError(try SharedRelationshipConsent(scope: scope, entry: newEntry, previous: record).validate(for: scope))
    }

    func testOnlyMemoryCanContainBoundedPhotoAndOnlyGoalsHaveProgress() throws {
        var memory = SharedRelationshipEntry(kind: .memory, title: "  A moment  ",
            photo: Data(count: SharedRelationshipEntry.maximumPhotoBytes))
        XCTAssertEqual(try memory.validated().title, "A moment")
        memory.photo = Data(count: SharedRelationshipEntry.maximumPhotoBytes + 1)
        XCTAssertThrowsError(try memory.validated())
        XCTAssertThrowsError(try SharedRelationshipEntry(kind: .response, title: "Question", photo: Data([1])).validated())
        XCTAssertThrowsError(try SharedRelationshipEntry(kind: .plan, title: "Tomorrow", progress: 20).validated())
        XCTAssertThrowsError(try SharedRelationshipEntry(kind: .goal, title: "Goal", progress: 101).validated())
        XCTAssertThrowsError(try SharedRelationshipEntry(kind: .memory, title: String(repeating: "é", count: 61)).validated())
    }

    func testOfflineSnapshotExpiresAndClockRollbackDoesNotExtendIt() {
        let start = Date(timeIntervalSince1970: 100)
        let window = RelationshipOfflineWindow(verifiedAt: start)
        XCTAssertFalse(window.permitsReading(at: start.addingTimeInterval(-1)))
        XCTAssertTrue(window.permitsReading(at: start.addingTimeInterval(44)))
        XCTAssertFalse(window.permitsReading(at: start.addingTimeInterval(45)))
    }
}
