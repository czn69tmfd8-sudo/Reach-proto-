import Foundation

/// ICE can arrive before SDP. Bound the queue and reject changed SDP for a one-shot room.
struct SignalingInbox {
    private(set) var description: ReachSessionDescription?
    private var candidates: [ReachIceCandidate] = []
    private var seen: Set<ReachIceCandidate> = []
    private(set) var ready = false
    private var drainOwner: UUID?

    mutating func accept(_ value: ReachSessionDescription) throws -> Bool {
        try ReachSignalingValidation.validate(value)
        if let description {
            guard description == value else { throw SignalingInboxError.changedDescription }
            return false
        }
        description = value
        return true
    }

    mutating func accept(_ candidate: ReachIceCandidate) throws {
        try ReachSignalingValidation.validate(candidate)
        guard !seen.contains(candidate) else { return }
        guard seen.count < 512 else { throw SignalingInboxError.tooManyCandidates }
        seen.insert(candidate)
        candidates.append(candidate)
    }

    mutating func remoteDescriptionApplied() throws {
        guard description != nil else { throw SignalingInboxError.missingDescription }
        ready = true
    }

    mutating func beginDrain() -> UUID? {
        guard ready, drainOwner == nil, !candidates.isEmpty else { return nil }
        let owner = UUID(); drainOwner = owner
        return owner
    }

    mutating func nextCandidate(owner: UUID) -> ReachIceCandidate? {
        guard drainOwner == owner, !candidates.isEmpty else { return nil }
        return candidates.removeFirst()
    }

    mutating func finishDrain(owner: UUID) {
        if drainOwner == owner { drainOwner = nil }
    }
}

enum SignalingInboxError: Error { case changedDescription, tooManyCandidates, missingDescription }
