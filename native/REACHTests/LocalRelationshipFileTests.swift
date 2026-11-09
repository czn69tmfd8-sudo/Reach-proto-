import XCTest
@testable import REACH

final class LocalRelationshipFileTests: XCTestCase {
    func testMissingFileStartsEmptyAndCommittedEntriesReload() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = LocalRelationshipFile(url: directory.appendingPathComponent("journal.json"))
        XCTAssertTrue(try file.load().entries.isEmpty)
        var journal = RelationshipJournal()
        try journal.save(RelationshipEntry(kind: .milestone, title: "Our first trip"))
        try file.write(journal)
        XCTAssertEqual(try file.load(), journal)
    }
    func testCorruptFileIsNotSilentlyOverwrittenByLoad() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let data = Data("not a journal".utf8); try data.write(to: url)
        XCTAssertThrowsError(try LocalRelationshipFile(url: url).load())
        XCTAssertEqual(try Data(contentsOf: url), data)
    }
    func testInvalidWritePreservesLastValidFile() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = LocalRelationshipFile(url: directory.appendingPathComponent("journal.json"))
        var journal = RelationshipJournal(); try journal.save(RelationshipEntry(kind: .memory, title: "Kept"))
        try file.write(journal)
        let before = try Data(contentsOf: file.url)
        var invalid = journal; invalid.version = 999
        XCTAssertThrowsError(try file.write(invalid))
        XCTAssertEqual(try Data(contentsOf: file.url), before)
    }
}
