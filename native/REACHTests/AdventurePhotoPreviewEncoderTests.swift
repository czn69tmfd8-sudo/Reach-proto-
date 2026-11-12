import ImageIO
import UIKit
import XCTest
@testable import REACH

final class AdventurePhotoPreviewEncoderTests: XCTestCase {
    func testEncoderBoundsBytesAndDimensionsAndProducesDecodableJPEG() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1_800, height: 1_200), format: format)
        let source = renderer.pngData { context in
            for y in stride(from: 0, to: 1_200, by: 8) {
                for x in stride(from: 0, to: 1_800, by: 8) {
                    let hue = CGFloat((x * 17 + y * 13) % 251) / 251
                    context.cgContext.setFillColor(UIColor(hue: hue, saturation: 0.78, brightness: 0.9, alpha: 1).cgColor)
                    context.cgContext.fill(CGRect(x: CGFloat(x), y: CGFloat(y), width: 8, height: 8))
                }
            }
        }
        let encoded = try XCTUnwrap(AdventurePhotoPreviewEncoder.encode(source))
        XCTAssertLessThanOrEqual(encoded.count, AdventurePhotoPreviewEncoder.maximumBytes)
        XCTAssertEqual(Array(encoded.prefix(3)), [0xff, 0xd8, 0xff])
        let image = try XCTUnwrap(UIImage(data: encoded)?.cgImage)
        XCTAssertLessThanOrEqual(max(image.width, image.height), 1_280)
        XCTAssertEqual(Double(image.width) / Double(image.height), 1.5, accuracy: 0.01)
    }

    func testRejectsUnreadableInput() {
        XCTAssertNil(AdventurePhotoPreviewEncoder.encode(Data([0, 1, 2, 3])))
    }

    func testQuotaActivationDefaultsClosedAndRejectsMissingOrFullCounters() throws {
        XCTAssertFalse(AdventureBookQuotaPolicy.enforcementEnabled)
        XCTAssertEqual(try AdventureBookQuotaPolicy.nextCount(from: 499), 500)
        XCTAssertThrowsError(try AdventureBookQuotaPolicy.nextCount(from: nil)) {
            XCTAssertEqual($0 as? AdventureBookQuotaError, .unavailable)
        }
        XCTAssertThrowsError(try AdventureBookQuotaPolicy.nextCount(from: 500)) {
            XCTAssertEqual($0 as? AdventureBookQuotaError, .full)
        }
    }
}
