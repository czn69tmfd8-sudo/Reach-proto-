import Foundation

// Phase 2 isolated domain prototype. No Firebase or production application imports.
public struct PairMembership: Sendable {
    public let userID: String
    public let pairID: String
    public let active: Bool
    public let revoked: Bool
    public let expiresAt: Date
    public init(userID: String, pairID: String, active: Bool, revoked: Bool = false, expiresAt: Date) {
        self.userID = userID; self.pairID = pairID; self.active = active
        self.revoked = revoked; self.expiresAt = expiresAt
    }
    public func permits(pairID: String, at now: Date) -> Bool {
        !userID.isEmpty && self.pairID == pairID && active && !revoked && expiresAt > now
    }
}

public enum MemoryValidationError: Error { case invalidIdentifier, invalidContent, invalidVersion }

public struct SharedMemory: Sendable {
    public let id: String
    public let pairID: String
    public let authorID: String
    public let version: Int
    public let deleted: Bool
    public init(id: String, pairID: String, authorID: String, version: Int, deleted: Bool = false) throws {
        guard !id.isEmpty && !id.contains("/") && !pairID.isEmpty && !pairID.contains("/") && !authorID.isEmpty else { throw MemoryValidationError.invalidIdentifier }
        guard version >= 0 else { throw MemoryValidationError.invalidVersion }
        self.id = id; self.pairID = pairID; self.authorID = authorID; self.version = version; self.deleted = deleted
    }
    public func canRead(_ member: PairMembership?, at now: Date) -> Bool {
        guard let member else { return false }
        return !deleted && member.permits(pairID: pairID, at: now)
    }
    public func canEdit(_ member: PairMembership?, expectedVersion: Int, at now: Date) -> Bool {
        canRead(member, at: now) && member?.userID == authorID && version == expectedVersion
    }
}

public struct PartnerStory: Sendable {
    public let authorID: String
    public let text: String
    public let version: Int
    public init(authorID: String, text: String, version: Int) throws {
        guard !authorID.isEmpty && version >= 0 else { throw MemoryValidationError.invalidIdentifier }
        guard text.count <= 12000 else { throw MemoryValidationError.invalidContent }
        self.authorID = authorID; self.text = text; self.version = version
    }
    public func canEdit(_ member: PairMembership?, memory: SharedMemory, expectedVersion: Int, at now: Date) -> Bool {
        memory.canRead(member, at: now) && member?.userID == authorID && version == expectedVersion
    }
}

public struct ConversationEntry: Sendable {
    public let id: String
    public let authorID: String
    public let text: String
    public init(id: String, authorID: String, text: String) throws {
        guard !id.isEmpty && !id.contains("/") && !authorID.isEmpty else { throw MemoryValidationError.invalidIdentifier }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && text.count <= 4000 else { throw MemoryValidationError.invalidContent }
        self.id = id; self.authorID = authorID; self.text = text
    }
    public func canAppend(_ member: PairMembership?, memory: SharedMemory, at now: Date) -> Bool {
        memory.canRead(member, at: now) && member?.userID == authorID
    }
}

public struct PhotoUploadIntent: Sendable {
    public let memoryID: String
    public let uploaderID: String
    public let mime: String
    public let bytes: Int
    public init(memoryID: String, uploaderID: String, mime: String, bytes: Int) throws {
        guard !memoryID.isEmpty && !uploaderID.isEmpty else { throw MemoryValidationError.invalidIdentifier }
        guard ["image/jpeg", "image/png", "image/heic"].contains(mime) && (1...10485760).contains(bytes) else { throw MemoryValidationError.invalidContent }
        self.memoryID = memoryID; self.uploaderID = uploaderID; self.mime = mime; self.bytes = bytes
    }
    public func canStage(_ member: PairMembership?, memory: SharedMemory, at now: Date) -> Bool {
        memory.id == memoryID && memory.canRead(member, at: now) && member?.userID == uploaderID && memory.authorID == uploaderID
    }
}

public enum OfflineEditDecision: Equatable { case apply, conflict, reject }
public func decideOfflineEdit(member: PairMembership?, memory: SharedMemory, expectedVersion: Int, now: Date) -> OfflineEditDecision {
    guard memory.canRead(member, at: now) && member?.userID == memory.authorID else { return .reject }
    return memory.version == expectedVersion ? .apply : .conflict
}
