import Foundation

/// Local recovery journal for an immutable Storage object. No Firebase access
/// is granted by this state machine; server rules remain authoritative.
struct AdventurePhotoUpload: Equatable, Sendable, Codable {
    enum Phase: String, Equatable, Sendable, Codable {
        case prepared
        case uploading
        case uploadedAwaitingMetadata
        case published
        case retryRequired
    }

    let pairCode: String
    let memoryID: String
    let photoID: String
    let ownerUID: String
    private(set) var phase: Phase = .prepared

    var objectPath: String? {
        AdventureBookPaths.photo(pairCode: pairCode, memoryID: memoryID, photoID: photoID)
    }

    mutating func begin(as uid: String) -> Bool {
        guard uid == ownerUID, objectPath != nil,
              phase == .prepared || phase == .retryRequired else { return false }
        phase = .uploading
        return true
    }

    mutating func uploaded(as uid: String) -> Bool {
        guard uid == ownerUID, phase == .uploading else { return false }
        phase = .uploadedAwaitingMetadata
        return true
    }

    mutating func metadataCommitted(as uid: String) -> Bool {
        guard uid == ownerUID, phase == .uploadedAwaitingMetadata else { return false }
        phase = .published
        return true
    }

    /// Interrupted upload: keep the same object ID. Before retrying, the
    /// transport must query object existence and verify ownership/size/hash.
    /// Never blindly overwrite an object that may already exist.
    mutating func interrupted(as uid: String) -> Bool {
        guard uid == ownerUID, phase == .uploading else { return false }
        phase = .retryRequired
        return true
    }
}
