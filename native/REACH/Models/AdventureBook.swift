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

/// Pure gallery navigation shared by the live book and its tests.
/// Gallery page 0 is the cover; gallery pages 1...N each hold eight memories.
/// Individual memories are opened by stable ID, never by a shifting page index.
struct AdventureGalleryPagination {
    static let memoriesPerSpread = 8

    static func spreadCount(memoryCount: Int) -> Int {
        max(1, max(0, memoryCount) / memoriesPerSpread + (max(0, memoryCount) % memoriesPerSpread == 0 ? 0 : 1))
    }

    static func memoryRange(spread: Int, memoryCount: Int) -> Range<Int> {
        let count = max(0, memoryCount)
        guard spread >= 0, spread < spreadCount(memoryCount: count) else { return 0..<0 }
        let start = spread * memoriesPerSpread
        guard start < count else { return 0..<0 }
        return start..<(start + min(memoriesPerSpread, count - start))
    }

    static func clampedPage(_ page: Int, memoryCount: Int) -> Int {
        min(max(0, page), spreadCount(memoryCount: memoryCount))
    }

    static func spread(forMemoryAt index: Int) -> Int? {
        guard index >= 0 else { return nil }
        return index / memoriesPerSpread + 1
    }

    /// The gallery page is 1-based; the cover occupies page zero.
    /// Keep the same memory in view after remote reordering when possible.
    static func page(forSelectedMemoryID id: String, orderedIDs: [String]) -> Int? {
        guard let index = orderedIDs.firstIndex(of: id) else { return nil }
        return spread(forMemoryAt: index)
    }

    /// Preserve ordering gaps; a new memory belongs after the highest existing
    /// page order, not after the number of memories currently loaded.
    /// A saturated order must be rejected rather than silently colliding.
    static func nextPageOrder(existing: [Int]) -> Int? {
        guard let maximum = existing.max() else { return 0 }
        guard maximum >= 0, maximum < Int.max else { return nil }
        return maximum + 1
    }

    static func selectedMemoryID(_ selectedID: String?, availableIDs: [String]) -> String? {
        guard let selectedID, availableIDs.contains(selectedID) else { return nil }
        return selectedID
    }
}
