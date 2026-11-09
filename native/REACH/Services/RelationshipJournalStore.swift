import Foundation
import Combine
import UIKit
import ImageIO

@MainActor
final class RelationshipJournalStore: ObservableObject {
    @Published private(set) var journal = RelationshipJournal()
    @Published private(set) var loadError: String?
    private let file: LocalRelationshipFile?
    init(url: URL? = nil) {
        let url = url ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("ReachPrivateJournal", isDirectory: true).appendingPathComponent("journal-v1.json")
        file = url.map { LocalRelationshipFile(url: $0) }
        reload()
    }
    func reload() {
        do {
            guard let file else { throw JournalError.unreadable }
            journal = try file.load(); loadError = nil
        } catch { loadError = error.localizedDescription }
    }
    func entries(_ kind: RelationshipEntry.Kind) -> [RelationshipEntry] {
        journal.entries.filter { $0.kind == kind }.sorted { $0.date > $1.date }
    }
    func save(_ entry: RelationshipEntry) throws {
        var next = journal; try next.save(entry); try commit(next)
    }
    func delete(_ entry: RelationshipEntry) throws {
        var next = journal; next.delete(id: entry.id); try commit(next)
    }
    private func commit(_ next: RelationshipJournal) throws {
        guard loadError == nil, let file else { throw JournalError.unreadable }
        do { try file.write(next) }
        catch let error as JournalError { throw error }
        catch { throw JournalError.storage }
        journal = next
    }
    /// Downsample and reencode selected memory photos; metadata is not retained.
    static func memoryPhoto(_ data: Data) throws -> Data {
        guard data.count <= 12_000_000, let source = CGImageSourceCreateWithData(data as CFData, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1280
              ] as CFDictionary), let jpeg = UIImage(cgImage: thumbnail).jpegData(compressionQuality: 0.72),
              jpeg.count <= 1_000_000 else { throw JournalError.invalidPhoto }
        return jpeg
    }
}
