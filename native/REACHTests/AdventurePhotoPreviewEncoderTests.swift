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

    func testReencodingStripsGPSAndSensitiveEXIFAndAppliesOrientation() throws {
        let inputImage = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 40)).image { context in
            context.cgContext.setFillColor(UIColor.red.cgColor)
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 80, height: 40))
        }
        let image = try XCTUnwrap(inputImage.cgImage)
        let input = try XCTUnwrap(CFDataCreateMutable(nil, 0))
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(input, "public.jpeg" as CFString, 1, nil))
        let metadata: [CFString: Any] = [
            kCGImagePropertyOrientation: 6,
            kCGImagePropertyGPSDictionary: [
                kCGImagePropertyGPSLatitude: 43.5, kCGImagePropertyGPSLatitudeRef: "N",
                kCGImagePropertyGPSLongitude: 81.5, kCGImagePropertyGPSLongitudeRef: "W"
            ],
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifDateTimeOriginal: "2024:01:02 03:04:05"]
        ]
        CGImageDestinationAddImage(destination, image, metadata as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let source = try XCTUnwrap(CGImageSourceCreateWithData(input, nil))
        let original = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        XCTAssertNotNil(original[kCGImagePropertyGPSDictionary])
        XCTAssertEqual(original[kCGImagePropertyOrientation] as? Int, 6)
        let originalEXIF = original[kCGImagePropertyExifDictionary] as? [CFString: Any]
        XCTAssertEqual(originalEXIF?[kCGImagePropertyExifDateTimeOriginal] as? String, "2024:01:02 03:04:05")

        let bytes = try XCTUnwrap(AdventurePhotoPreviewEncoder.encode(input as Data))
        let reencoded = try XCTUnwrap(CGImageSourceCreateWithData(bytes as CFData, nil))
        let result = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(reencoded, 0, nil) as? [CFString: Any])
        XCTAssertNil(result[kCGImagePropertyGPSDictionary])
        let exif = result[kCGImagePropertyExifDictionary] as? [CFString: Any]
        XCTAssertNil(exif?[kCGImagePropertyExifDateTimeOriginal])
        let rotated = try XCTUnwrap(AdventurePhotoPreviewEncoder.thumbnail(bytes, maximumEdge: 400))
        XCTAssertLessThan(rotated.width, rotated.height)
    }

    func testRejectsUnreadableInput() {
        XCTAssertNil(AdventurePhotoPreviewEncoder.encode(Data([0, 1, 2, 3])))
    }

    func testQuotaActivationDefaultsClosedAndRejectsMissingOrFullCounters() throws {
        XCTAssertFalse(AdventureBookAvailability.liveSharedBookEnabled)
        XCTAssertEqual(try AdventureBookQuotaPolicy.nextCount(from: 499), 500)
        XCTAssertThrowsError(try AdventureBookQuotaPolicy.nextCount(from: nil)) {
            XCTAssertEqual($0 as? AdventureBookQuotaError, .unavailable)
        }
        XCTAssertThrowsError(try AdventureBookQuotaPolicy.nextCount(from: 500)) {
            XCTAssertEqual($0 as? AdventureBookQuotaError, .full)
        }
    }
}
