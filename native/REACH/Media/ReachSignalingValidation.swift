import Foundation

/// Validates untrusted signaling payloads before handing them to a native WebRTC peer.
enum ReachSignalingValidation {
    static let maximumSDPBytes = 256 * 1024
    static let maximumCandidateBytes = 8 * 1024

    static func validate(_ description: ReachSessionDescription) throws {
        guard !description.sdp.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              description.sdp.utf8.count <= maximumSDPBytes else {
            throw ReachSignalingValidationError.invalidDescription
        }
    }

    static func validate(_ candidate: ReachIceCandidate) throws {
        guard !candidate.sdp.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              candidate.sdp.utf8.count <= maximumCandidateBytes,
              candidate.sdpMLineIndex >= 0,
              (candidate.sdpMid?.utf8.count ?? 0) <= 256 else {
            throw ReachSignalingValidationError.invalidCandidate
        }
    }
}

enum ReachSignalingValidationError: Error, Equatable {
    case invalidDescription
    case invalidCandidate
}
