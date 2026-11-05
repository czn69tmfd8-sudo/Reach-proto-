import Foundation

/// ICE can arrive before SDP. Bound the queue and reject changed SDP for a one-shot room.
struct SignalingInbox {
    private(set) var description: ReachSessionDescription?
    private var candidates: [ReachIceCandidate] = []
    private var seen: Set<ReachIceCandidate> = []
    private(set) var ready = false

    mutating func accept(_ value: ReachSessionDescription) throws -> Bool {
        try ReachSignalingValidation.validate(value)
        if let description {
            guard description == value else { throw SignalingInboxError.changedDescription }
            return false
        }
        description = value
        return true
    }

    mutating func accept(_ candidate: ReachIceCandidate) throws -> [ReachIceCandidate] {
        try ReachSignalingValidation.validate(candidate)
        guard !seen.contains(candidate) else { return [] }
        guard seen.count < 512 else { throw SignalingInboxError.tooManyCandidates }
        seen.insert(candidate)
        if ready { return [candidate] }
        candidates.append(candidate)
        return []
    }

    mutating func remoteDescriptionApplied() -> [ReachIceCandidate] {
        ready = true
        defer { candidates.removeAll() }
        return candidates
    }
}

enum SignalingInboxError: Error { case changedDescription, tooManyCandidates }
