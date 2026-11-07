import XCTest
@testable import REACH

final class RelationshipJournalTests: XCTestCase {
    func testEveryContentKindRoundTripsAndCanBeEditedAndDeleted() throws {
        for kind in RelationshipEntry.Kind.allCases {
            var journal = RelationshipJournal()
            var entry = RelationshipEntry(kind: kind, title: "A moment", body: "Personal words")
            try journal.save(entry)
            entry.body = "Revised"; try journal.save(entry)
            XCTAssertEqual(journal.entries.count, 1)
            let decoded = try JSONDecoder().decode(RelationshipJournal.self, from: JSONEncoder().encode(journal))
            XCTAssertEqual(decoded, journal)
            journal.delete(id: entry.id)
            XCTAssertTrue(journal.entries.isEmpty)
        }
    }
    func testWhitespaceAndBoundsValidateWithoutMutatingExistingJournal() throws {
        var journal = RelationshipJournal()
        try journal.save(RelationshipEntry(kind: .memory, title: "  Lake  "))
        XCTAssertEqual(journal.entries.first?.title, "Lake")
        let before = journal
        for entry in [RelationshipEntry(kind: .memory, title: "   "),
                      RelationshipEntry(kind: .memory, title: String(repeating: "a", count: 121)),
                      RelationshipEntry(kind: .question, title: "Question", body: String(repeating: "a", count: 6001)),
                      RelationshipEntry(kind: .dateIdea, title: "Date", category: String(repeating: "a", count: 41))] {
            XCTAssertThrowsError(try journal.save(entry))
            XCTAssertEqual(journal, before)
        }
    }
    func testOnlyMemoriesAcceptBoundedPhotos() throws {
        var journal = RelationshipJournal()
        try journal.save(RelationshipEntry(kind: .memory, title: "Photo", photo: Data([1,2,3])))
        XCTAssertThrowsError(try journal.save(RelationshipEntry(kind: .question, title: "Private", photo: Data([1]))))
        XCTAssertThrowsError(try journal.save(RelationshipEntry(kind: .memory, title: "Large", photo: Data(repeating: 1, count: 1_000_001))))
    }
    func testCapacityAllowsEditingButRejectsNewItemsAtomically() throws {
        var journal = RelationshipJournal()
        for _ in 0..<RelationshipJournal.maximumEntries { try journal.save(RelationshipEntry(kind: .memory, title: "Moment")) }
        var entry = try XCTUnwrap(journal.entries.first); entry.title = "Revised"
        try journal.save(entry)
        let before = journal
        XCTAssertThrowsError(try journal.save(RelationshipEntry(kind: .memory, title: "Overflow")))
        XCTAssertEqual(journal, before)
    }
    func testTotalPhotoBudgetIsEnforced() throws {
        var journal = RelationshipJournal()
        for _ in 0..<8 { try journal.save(RelationshipEntry(kind: .memory, title: "Photo", photo: Data(repeating: 0, count: 1_000_000))) }
        XCTAssertThrowsError(try journal.save(RelationshipEntry(kind: .memory, title: "Too much", photo: Data([0]))))
        XCTAssertEqual(journal.entries.count, 8)
    }
    func testDuplicateIDsAndFutureSchemaAreRejectedOnLoad() throws {
        let entry = RelationshipEntry(kind: .memory, title: "Original")
        let encoder = JSONEncoder()
        let duplicate = "{\"version\":1,\"entries\":[\(String(decoding: try encoder.encode(entry), as: UTF8.self)),\(String(decoding: try encoder.encode(entry), as: UTF8.self))]}"
        let journal = try JSONDecoder().decode(RelationshipJournal.self, from: Data(duplicate.utf8))
        XCTAssertThrowsError(try journal.validate())
        var future = RelationshipJournal(); future.version = 2
        XCTAssertThrowsError(try future.validate())
    }
    func testDailyPromptsAreStableForTheSameLocalDay() {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = Date(timeIntervalSince1970: 1_800_000_000)
        let start = calendar.startOfDay(for: day)
        XCTAssertEqual(RelationshipPrompts.daily(RelationshipPrompts.questions, on: start, calendar: calendar),
                       RelationshipPrompts.daily(RelationshipPrompts.questions, on: start.addingTimeInterval(3600), calendar: calendar))
        XCTAssertEqual(RelationshipPrompts.daily([], on: day), "")
    }
    func testReminderDismissalAndDateOrganizationSurviveEncoding() throws {
        var journal = RelationshipJournal()
        try journal.save(RelationshipEntry(kind: .reminder, title: "A gentle reminder", status: .dismissed))
        try journal.save(RelationshipEntry(kind: .dateIdea, title: "Walk", category: "Outdoors", status: .planned))
        let restored = try JSONDecoder().decode(RelationshipJournal.self, from: JSONEncoder().encode(journal))
        XCTAssertEqual(restored.entries.map(\.status), [.dismissed, .planned])
        XCTAssertEqual(restored.entries.last?.category, "Outdoors")
    }
}
