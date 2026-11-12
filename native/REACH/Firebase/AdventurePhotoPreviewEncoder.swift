import ImageIO
import UIKit

/// Local encoder for the private Firestore preview candidate. The live
/// Adventure Book never calls this encoder or enables the prototype transport.
enum AdventurePhotoPreviewEncoder {
    static let maximumBytes = 256 * 1024
    static let maximumInputBytes = 25 * 1024 * 1024

    static func encode(_ input: Data) -> Data? {
        guard !input.isEmpty, input.count <= maximumInputBytes,
              let source = CGImageSourceCreateWithData(input as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              (1...20_000).contains(width), (1...20_000).contains(height),
              width * height <= 80_000_000 else { return nil }

        for edge in [1_280, 1_080, 900, 720, 576] {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: min(edge, max(width, height)),
                kCGImageSourceShouldCacheImmediately: true
            ]
            guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                return nil
            }
            let image = UIImage(cgImage: thumbnail)
            for quality: CGFloat in [0.86, 0.80, 0.74] {
                if let bytes = image.jpegData(compressionQuality: quality), bytes.count <= maximumBytes {
                    return bytes
                }
            }
        }
        return nil
    }
}
