import Foundation

/// Durable metadata-only recovery record. Never persists Firebase credentials,
/// public download tokens, or photo bytes in the journal.
struct AdventurePhotoRecoveryRecord: Codable, Equatable, Sendable {
    let upload: AdventurePhotoUpload
    let sha256: String
    let byteCount: Int
    let caption: String
    let position: Int

    func canResume(as uid: String, withHash hash: String, byteCount count: Int) -> Bool {
        upload.ownerUID == uid && upload.objectPath != nil
            && upload.phase != .published
            && sha256 == hash && byteCount == count
            && sha256.count == 64 && sha256.allSatisfy { $0.isHexDigit }
            && count > 0 && count <= 15_728_640
            && caption.utf8.count <= 500 && position >= 0
    }
}

/// Protected app-container journal. A recovered entry never authorizes an
/// upload: the transport still rechecks Firebase authentication and rules.
/// Caller must reselect matching original bytes after an app restart.
struct AdventurePhotoRecoveryJournal {
    let fileURL: URL

    func save(_ record: AdventurePhotoRecoveryRecord) throws {
        let data = try JSONEncoder().encode(record)
        #if canImport(Darwin)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        #else
        try data.write(to: fileURL, options: .atomic)
        #endif
    }

    func load() throws -> AdventurePhotoRecoveryRecord? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return try JSONDecoder().decode(AdventurePhotoRecoveryRecord.self,
                                        from: Data(contentsOf: fileURL))
    }

    func clear() throws {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }
}
