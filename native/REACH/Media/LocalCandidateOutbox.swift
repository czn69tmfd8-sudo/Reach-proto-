import Foundation

/// One room's local ICE queue. Only the owning controller drains it; SDK repeat
/// callbacks cannot create duplicate writes or unbounded per-candidate tasks.
struct LocalCandidateOutbox {
    private var pending: [ReachIceCandidate] = []
    private var seen: Set<ReachIceCandidate> = []
    static let limit = 512

    mutating func enqueue(_ candidate: ReachIceCandidate) throws {
        try ReachSignalingValidation.validate(candidate)
        guard !seen.contains(candidate) else { return }
        guard seen.count < Self.limit else { throw SignalingInboxError.tooManyCandidates }
        seen.insert(candidate)
        pending.append(candidate)
    }

    mutating func next() -> ReachIceCandidate? {
        guard !pending.isEmpty else { return nil }
        return pending.removeFirst()
    }
}
