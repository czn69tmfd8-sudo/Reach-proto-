import XCTest
import UIKit
@testable import REACH

final class ReachAppearanceStoreTests: XCTestCase {
    @MainActor func testLocalPreferencesPersistWithoutPairingIdentity() async throws {
        let suite = "reach.appearance.test." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ReachAppearanceStore(defaults: defaults)
        store.preferences.ownName = "Custom name"
        store.preferences.personalMessage = "Optional words"
        let restored = ReachAppearanceStore(defaults: defaults)
        XCTAssertEqual(restored.preferences, store.preferences)
    }
    @MainActor func testSelectedPhotoPersistsAndResetRestoresOriginalDefault() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ReachAppearanceStore(photoDirectory: directory)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { context in
            UIColor.purple.setFill(); context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        try store.setPhoto(try XCTUnwrap(image.pngData()), for: .background)
        XCTAssertNotNil(store.backgroundPhoto)
        XCTAssertNotNil(ReachAppearanceStore(photoDirectory: directory).backgroundPhoto)
        try store.setPhoto(nil, for: .background)
        XCTAssertNil(store.backgroundPhoto)
        if case .originalSunset = store.background {} else { XCTFail("Reset must restore the exact default asset") }
    }
    @MainActor func testInvalidPhotoNeverCreatesAnAppearanceFile() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ReachAppearanceStore(photoDirectory: directory)
        XCTAssertThrowsError(try store.setPhoto(Data("not an image".utf8), for: .own))
        XCTAssertNil(store.ownPhoto)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("own.jpg").path))
    }
}
