import SwiftUI
import UIKit
import ImageIO

/// Local appearance only: no Firebase writes, uploads or Photos-library access.
/// PhotosPicker supplies only the image explicitly selected by the user.
@MainActor
final class ReachAppearanceStore: ObservableObject {
    enum Photo: String, CaseIterable, Identifiable, Hashable, Sendable {
        case own, partner, background
        var id: String { rawValue }
        var label: String {
            switch self {
            case .own: return "Your photo"
            case .partner: return "Partner photo (local)"
            case .background: return "Background photo"
            }
        }
    }
    @Published var preferences: ReachAppearancePreferences { didSet { savePreferences() } }
    @Published private(set) var ownPhoto: UIImage?
    @Published private(set) var partnerPhoto: UIImage?
    @Published private(set) var backgroundPhoto: UIImage?
    private let defaults: UserDefaults
    private let directory: URL?
    private static let key = "reach.native.appearance.v1"

    init(defaults: UserDefaults = .standard, photoDirectory: URL? = nil) {
        self.defaults = defaults
        preferences = defaults.data(forKey: Self.key).flatMap { try? JSONDecoder().decode(ReachAppearancePreferences.self, from: $0) } ?? ReachAppearancePreferences()
        directory = photoDirectory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("ReachAppearance", isDirectory: true)
        ownPhoto = Self.load(.own, directory: directory)
        partnerPhoto = Self.load(.partner, directory: directory)
        backgroundPhoto = Self.load(.background, directory: directory)
    }
    var background: ReachHomeBackgroundSource {
        backgroundPhoto.map { .couplePhoto($0) } ?? .originalSunset
    }
    func image(for slot: Photo) -> UIImage? {
        switch slot { case .own: return ownPhoto; case .partner: return partnerPhoto; case .background: return backgroundPhoto }
    }
    func setPhoto(_ data: Data?, for slot: Photo) throws {
        guard let directory else { throw AppearanceError.storage }
        let url = directory.appendingPathComponent(slot.rawValue + ".jpg")
        var image: UIImage?
        if let data {
            guard data.count <= 12_000_000,
                  let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: slot == .background ? 2048 : 1024
                  ] as CFDictionary) else { throw AppearanceError.image }
            let selected = UIImage(cgImage: thumbnail)
            guard let encoded = selected.jpegData(compressionQuality: 0.9) else { throw AppearanceError.image }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var folder = directory
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            try folder.setResourceValues(values)
            try encoded.write(to: url, options: [.atomic, .completeFileProtection])
            image = selected
        } else if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        switch slot { case .own: ownPhoto = image; case .partner: partnerPhoto = image; case .background: backgroundPhoto = image }
    }
    private func savePreferences() {
        if let data = try? JSONEncoder().encode(preferences) { defaults.set(data, forKey: Self.key) }
    }
    private static func load(_ slot: Photo, directory: URL?) -> UIImage? {
        guard let directory, let data = try? Data(contentsOf: directory.appendingPathComponent(slot.rawValue + ".jpg")) else { return nil }
        return UIImage(data: data)
    }
    enum AppearanceError: LocalizedError {
        case storage, image
        var errorDescription: String? {
            switch self { case .storage: return "Photo storage is unavailable."; case .image: return "Choose a supported image smaller than 12 MB." }
        }
    }
}
