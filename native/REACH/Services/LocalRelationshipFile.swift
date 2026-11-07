import Foundation

/// No networking. Commit the file before publishing any in-memory change.
struct LocalRelationshipFile {
    let url: URL
    static let maximumFileBytes = 12_000_000
    #if os(iOS)
    static let writingOptions: Data.WritingOptions = [.atomic, .completeFileProtection]
    #else
    static let writingOptions: Data.WritingOptions = .atomic
    #endif

    func load() throws -> RelationshipJournal {
        guard FileManager.default.fileExists(atPath: url.path) else { return RelationshipJournal() }
        do {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= Self.maximumFileBytes else { throw JournalError.capacity }
            let journal = try JSONDecoder().decode(RelationshipJournal.self, from: Data(contentsOf: url))
            try journal.validate()
            return journal
        } catch let error as JournalError { throw error }
        catch { throw JournalError.unreadable }
    }
    func write(_ journal: RelationshipJournal) throws {
        try journal.validate()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(journal)
        guard data.count <= Self.maximumFileBytes else { throw JournalError.capacity }
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var folder = directory
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try folder.setResourceValues(values)
        try data.write(to: url, options: Self.writingOptions)
    }
}
