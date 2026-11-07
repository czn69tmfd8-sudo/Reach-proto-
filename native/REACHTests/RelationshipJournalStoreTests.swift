import XCTest
import UIKit
import ImageIO
import UniformTypeIdentifiers
@testable import REACH

final class RelationshipJournalStoreTests: XCTestCase {
    @MainActor func testStoreCRUDPersistsAcrossInstances() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("journal.json"), entry = RelationshipEntry(kind: .memory, title: "A moment")
        let store = RelationshipJournalStore(url: url)
        try store.save(entry)
        XCTAssertEqual(RelationshipJournalStore(url: url).entries(.memory), [entry])
        try store.delete(entry)
        XCTAssertTrue(RelationshipJournalStore(url: url).journal.entries.isEmpty)
    }
    @MainActor func testFailedLoadDisablesWritesWithoutOverwritingFile() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let original = Data("unreadable".utf8); try original.write(to: url)
        let store = RelationshipJournalStore(url: url)
        XCTAssertNotNil(store.loadError)
        XCTAssertThrowsError(try store.save(RelationshipEntry(kind: .memory, title: "New")))
        XCTAssertEqual(try Data(contentsOf: url), original)
    }
    @MainActor func testMemoryPhotoStripsMetadataAndInvalidBytesAreRejected() async throws {
        let photo = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { context in
            UIColor.purple.setFill(); context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        let source = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(source, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try XCTUnwrap(photo.cgImage), [
            kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 42.0, kCGImagePropertyGPSLatitudeRef: "N"]
        ] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let data = try RelationshipJournalStore.memoryPhoto(source as Data)
        let decoded = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(decoded, 0, nil) as? [String: Any])
        XCTAssertNil(properties[kCGImagePropertyGPSDictionary as String])
        XCTAssertNotNil(UIImage(data: data)); XCTAssertLessThanOrEqual(data.count, 1_000_000)
        XCTAssertThrowsError(try RelationshipJournalStore.memoryPhoto(Data("invalid".utf8)))
    }
    @MainActor func testFailedDiskWriteDoesNotPublishUncommittedEntry() async throws {
        let blocker = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: blocker) }
        try Data("a file, not a folder".utf8).write(to: blocker)
        let store = RelationshipJournalStore(url: blocker.appendingPathComponent("journal.json"))
        XCTAssertThrowsError(try store.save(RelationshipEntry(kind: .memory, title: "Not committed")))
        XCTAssertTrue(store.journal.entries.isEmpty)
    }
    @MainActor func testJournalFileIsProtectedAndExcludedFromBackup() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("journal.json")
        let store = RelationshipJournalStore(url: url)
        try store.save(RelationshipEntry(kind: .memory, title: "Private"))
        XCTAssertEqual(try folder.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        XCTAssertEqual(attributes[.protectionKey] as? FileProtectionType, .complete)
    }
    @MainActor func testOriginalSunsetIsAvailableFromTheCompiledAssetCatalog() async {
        XCTAssertNotNil(UIImage(named: "OriginalSunset", in: Bundle.main, compatibleWith: nil))
    }

}
