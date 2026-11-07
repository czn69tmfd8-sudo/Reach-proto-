import UIKit
import XCTest
@testable import REACH

final class SharedMemoryPhotoTests: XCTestCase {
    @MainActor func testSharedPhotoAndDisplayThumbnailStayBounded() async throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let source = UIGraphicsImageRenderer(size: CGSize(width: 1920, height: 1080), format: format).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1920, height: 1080))
        }
        let encoded = try SharedMemoryPhoto.prepare(XCTUnwrap(source.jpegData(compressionQuality: 0.9)))
        XCTAssertLessThanOrEqual(encoded.count, SharedRelationshipEntry.maximumPhotoBytes)
        let shared = try XCTUnwrap(UIImage(data: encoded)?.cgImage)
        XCTAssertEqual(max(shared.width, shared.height), 960)
        let thumbnail = try XCTUnwrap(SharedMemoryPhoto.thumbnail(encoded, maxDimension: 640)?.cgImage)
        XCTAssertEqual(max(thumbnail.width, thumbnail.height), 640)
    }

    @MainActor func testInvalidSharedPhotoDoesNotProduceAPreview() async {
        let invalid = Data([0x00, 0x01, 0x02])
        XCTAssertThrowsError(try SharedMemoryPhoto.prepare(invalid))
        XCTAssertNil(SharedMemoryPhoto.thumbnail(invalid, maxDimension: 640))
    }
}
