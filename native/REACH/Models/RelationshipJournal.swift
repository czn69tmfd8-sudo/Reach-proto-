import Foundation

/// All entries are private to this installation. No UID or pair code is inferred.
struct RelationshipEntry: Codable, Equatable, Identifiable, Sendable {
    enum Kind: String, Codable, CaseIterable, Identifiable, Sendable {
        case memory, question, dateIdea, reminder, milestone
        var id: String { rawValue }
        var label: String {
            switch self {
            case .memory: return "Memory"
            case .question: return "Question response"
            case .dateIdea: return "Date idea"
            case .reminder: return "Reminder"
            case .milestone: return "Milestone"
            }
        }
    }
    enum Status: String, Codable, CaseIterable, Sendable { case saved, planned, completed, dismissed }
    let id: UUID
    var kind: Kind
    var title: String
    var body: String
    var date: Date
    var category: String
    var status: Status
    var photo: Data?

    init(id: UUID = UUID(), kind: Kind, title: String = "", body: String = "", date: Date = Date(),
         category: String = "", status: Status = .saved, photo: Data? = nil) {
        self.id = id; self.kind = kind; self.title = title; self.body = body
        self.date = date; self.category = category; self.status = status; self.photo = photo
    }
    func validated() throws -> Self {
        var value = self
        value.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        value.body = body.trimmingCharacters(in: .whitespacesAndNewlines)
        value.category = category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.title.isEmpty, value.title.count <= 120, value.body.count <= 6000,
              value.category.count <= 40, date.timeIntervalSince1970.isFinite,
              (photo?.count ?? 0) <= 1_000_000,
              photo == nil || kind == .memory else { throw JournalError.invalidEntry }
        return value
    }
}

struct RelationshipJournal: Codable, Equatable, Sendable {
    var version = 1
    private(set) var entries: [RelationshipEntry] = []
    static let maximumEntries = 200
    static let maximumPhotoBytes = 8_000_000

    func validate() throws {
        guard version == 1 else { throw JournalError.unsupportedVersion }
        guard entries.count <= Self.maximumEntries, Set(entries.map(\.id)).count == entries.count,
              entries.reduce(0, { $0 + ($1.photo?.count ?? 0) }) <= Self.maximumPhotoBytes else { throw JournalError.capacity }
        for entry in entries { _ = try entry.validated() }
    }
    mutating func save(_ entry: RelationshipEntry) throws {
        var next = self
        let entry = try entry.validated()
        if let index = next.entries.firstIndex(where: { $0.id == entry.id }) { next.entries[index] = entry }
        else { next.entries.append(entry) }
        try next.validate()
        self = next
    }
    mutating func delete(id: UUID) { entries.removeAll { $0.id == id } }
}

enum JournalError: LocalizedError, Equatable {
    case invalidEntry, invalidPhoto, storage, capacity, unsupportedVersion, unreadable
    var errorDescription: String? {
        switch self {
        case .invalidEntry: return "Add a title up to 120 characters. Notes may contain up to 6,000 characters; memory photos must be smaller than 1 MB."
        case .invalidPhoto: return "Choose a supported photograph smaller than 12 MB. REACH keeps a resized copy up to 1 MB."
        case .storage: return "Your entry could not be saved. No in-memory changes were applied. Check available storage and try again."
        case .capacity: return "This local journal supports 200 entries and 8 MB of photos. Remove an entry or photo before adding more."
        case .unsupportedVersion: return "This journal needs a newer version of REACH. Its contents have not been changed."
        case .unreadable: return "Your local journal could not be opened. Nothing has been overwritten. Try again after unlocking your iPhone."
        }
    }
}

/// Suggestions are prompts only, never manufactured couple activity.
enum RelationshipPrompts {
    static let questions = [
        "What made you feel cared for today?", "What would help you feel closer this week?",
        "Which small moment together would you like to relive?", "What are you looking forward to?",
        "What is one thing you appreciate about us?", "How can I support you tomorrow?",
        "What would you like us to make time for?"
    ]
    static let reminders = [
        "Share one thing you appreciate about each other.", "Make room to listen without rushing to solve.",
        "Ask how your partner would like to be supported today.", "Choose a small moment to spend together."
    ]
    static let dateIdeas = ["Cook the same recipe together", "Take a walk and share the view", "Plan a future weekend", "Read a chapter together", "Have a music night"]
    static func daily(_ values: [String], on date: Date, calendar: Calendar = .current) -> String {
        guard !values.isEmpty else { return "" }
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 1
        return values[(max(1, day) - 1) % values.count]
    }
}
