import Foundation

/// Deterministic, offline book operations. The caller is responsible for
/// authenticating the user and the backend must independently enforce access.
struct AdventureBook: Equatable, Sendable, Codable {
    let pairCode: String
    var memories: [AdventureMemory]

    var orderedMemories: [AdventureMemory] {
        memories.sorted {
            if $0.pageOrder != $1.pageOrder { return $0.pageOrder < $1.pageOrder }
            if $0.occurredAt != $1.occurredAt { return $0.occurredAt < $1.occurredAt }
            return $0.id < $1.id
        }
    }

    func isValid(members: Set<String>) -> Bool {
        SharedContentPolicy.pairCode(pairCode)
            && Set(memories.map(\.id)).count == memories.count
            && memories.allSatisfy { $0.pairCode == pairCode && $0.isValid(members: members) }
    }

    mutating func insert(_ memory: AdventureMemory, as uid: String, members: Set<String>) -> Bool {
        guard members.count == 2, members.contains(uid), uid == memory.creatorUID,
              memory.pairCode == pairCode, memory.isValid(members: members),
              !memories.contains(where: { $0.id == memory.id }) else { return false }
        memories.append(memory)
        return true
    }

    mutating func updateStory(memoryID: String, as uid: String, text: String,
                              at date: Date, members: Set<String>) -> Bool {
        guard let index = memories.firstIndex(where: { $0.id == memoryID }) else { return false }
        return memories[index].updateStory(as: uid, text: text, at: date, members: members)
    }

    mutating func addComment(memoryID: String, comment: AdventureMemory.Comment,
                             as uid: String, members: Set<String>) -> Bool {
        guard let index = memories.firstIndex(where: { $0.id == memoryID }) else { return false }
        return memories[index].addComment(comment, as: uid, members: members)
    }

    /// Reordering is intentionally a separate action, not a side effect of edits.
    /// Caller supplies exactly the existing IDs, with no duplicates or omissions.
    mutating func reorder(_ ids: [String], as uid: String, members: Set<String>) -> Bool {
        guard members.count == 2, members.contains(uid), ids.count == memories.count,
              Set(ids).count == ids.count, Set(ids) == Set(memories.map(\.id)) else { return false }
        let positions = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($0.element, $0.offset) })
        for index in memories.indices {
            guard let position = positions[memories[index].id] else { return false }
            memories[index].pageOrder = position
        }
        return true
    }
}
