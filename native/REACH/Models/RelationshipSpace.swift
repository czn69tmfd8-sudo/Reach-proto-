import Foundation

struct RelationshipScope: Equatable, Sendable {
    let uid: String
    let pairCode: String

    static func resolve(uid: String, code: String, pair: PairRecord?) -> Self? {
        guard SharedContentPolicy.documentID(uid), SharedContentPolicy.pairCode(code),
              let pair, pair.revoked == false, pair.contains(uid: uid),
              let partner = pair.partnerUID(for: uid), partner != uid,
              SharedContentPolicy.documentID(partner) else { return nil }
        return Self(uid: uid, pairCode: code)
    }
}

enum SharedRelationshipKind: String, CaseIterable, Identifiable, Sendable {
    case memory, milestone, goal, response, plan
    var id: Self { self }
    var title: String {
        switch self {
        case .memory: "Memory"
        case .milestone: "Milestone"
        case .goal: "Goal"
        case .response: "Response"
        case .plan: "Plan"
        }
    }
}

struct SharedRelationshipEntry: Identifiable, Equatable, Sendable {
    static let maximumPhotoBytes = 250_000
    let id: UUID
    let kind: SharedRelationshipKind
    var title: String
    var caption: String
    var date: Date
    var progress: Int = 0
    var photo: Data?

    init(id: UUID = UUID(), kind: SharedRelationshipKind, title: String = "",
         caption: String = "", date: Date = Date(), progress: Int = 0, photo: Data? = nil) {
        self.id = id
        self.kind = kind
        self.title = title
        self.caption = caption
        self.date = date
        self.progress = progress
        self.photo = photo
    }

    /// Only called from the explicit Share a copy action. The private ID is never used remotely.
    static func memoryCopy(of privateEntry: RelationshipEntry, photo: Data?) -> Self {
        Self(kind: .memory, title: privateEntry.title, caption: privateEntry.body, date: privateEntry.date, photo: photo)
    }

    func validated() throws -> Self {
        var clean = self
        clean.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        clean.caption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.title.isEmpty, clean.title.utf8.count <= 120, clean.caption.utf8.count <= 6_000,
              date.timeIntervalSince1970.isFinite, (0...100).contains(progress),
              kind == .goal || progress == 0, kind == .memory || photo == nil,
              photo.map({ !$0.isEmpty && $0.count <= Self.maximumPhotoBytes }) ?? true else {
            throw RelationshipSpaceError.invalid
        }
        return clean
    }
}

struct SharedRelationshipRecord: Identifiable, Equatable, Sendable {
    let entry: SharedRelationshipEntry
    let scope: RelationshipScope
    let authorUID: String
    let version: String
    var id: UUID { entry.id }

    func isOwned(by scope: RelationshipScope?) -> Bool { self.scope == scope && scope?.uid == authorUID }
}

/// Created only by an explicit sharing confirmation. Scope and content travel together.
struct SharedRelationshipConsent: Equatable, Sendable {
    let scope: RelationshipScope
    let entry: SharedRelationshipEntry
    let previous: SharedRelationshipRecord?

    var precondition: URLQueryItem {
        previous.map { URLQueryItem(name: "currentDocument.updateTime", value: $0.version) }
            ?? URLQueryItem(name: "currentDocument.exists", value: "false")
    }

    func validate(for activeScope: RelationshipScope) throws {
        guard scope == activeScope else { throw RelationshipSpaceError.unauthorized }
        _ = try entry.validated()
        if let previous {
            guard previous.isOwned(by: scope), previous.id == entry.id,
                  previous.entry.kind == entry.kind else { throw RelationshipSpaceError.unauthorized }
        }
    }
}

struct RelationshipOfflineWindow: Sendable {
    let verifiedAt: Date
    static let duration: TimeInterval = 45
    func permitsReading(at date: Date) -> Bool {
        (0..<Self.duration).contains(date.timeIntervalSince(verifiedAt))
    }
}

enum RelationshipSpaceError: LocalizedError, Equatable {
    case unauthorized, unavailable, unconfirmed, conflict, invalid, malformed, missing

    var errorDescription: String? {
        switch self {
        case .unauthorized: "Shared access is unavailable. Check pairing and staging access."
        case .unavailable: "Couldn’t reach the shared space. Try again when you’re online."
        case .unconfirmed: "The server may have received this change. Refresh to check, or retry this same draft when you’re online."
        case .conflict: "This entry changed or was removed. Refresh and reopen it before editing again."
        case .invalid: "Add a title. Use up to 120 bytes for the title, 6,000 for the text, and 250 KB for a shared photo."
        case .missing: "This shared entry was removed."
        case .malformed: "An unexpected response prevented this space from loading."
        }
    }
}
