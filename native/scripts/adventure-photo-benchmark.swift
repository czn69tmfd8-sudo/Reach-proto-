import Foundation
import ImageIO

for path in CommandLine.arguments.dropFirst() {
    let url = URL(fileURLWithPath: path)
    let original = try Data(contentsOf: url)
    guard let preview = AdventurePhotoPreviewEncoder.encode(original),
          let source = CGImageSourceCreateWithData(preview as CFData, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw CocoaError(.fileReadCorruptFile, userInfo: [NSFilePathErrorKey: path])
    }
    print("\(url.lastPathComponent) input=\(original.count) output=\(preview.count) pixels=\(image.width)x\(image.height)")
}
