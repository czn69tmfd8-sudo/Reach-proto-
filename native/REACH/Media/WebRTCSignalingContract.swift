import Foundation

struct ReachSessionDescription: Equatable, Codable, Sendable {
    enum Kind: String, Codable, Sendable {
        case offer
        case answer
    }

    let kind: Kind
    let sdp: String
}

struct ReachIceCandidate: Equatable, Hashable, Codable, Sendable {
    let sdp: String
    let sdpMid: String?
    let sdpMLineIndex: Int32
}

@MainActor
protocol ReachSignalingTransport {
    func publishDescription(
        _ description: ReachSessionDescription,
        roomID: String,
        role: ReachMediaRole
    ) async throws

    func observeRemoteDescription(
        roomID: String,
        role: ReachMediaRole
    ) -> AsyncThrowingStream<ReachSessionDescription, Error>

    func publishCandidate(
        _ candidate: ReachIceCandidate,
        roomID: String,
        role: ReachMediaRole
    ) async throws

    func observeRemoteCandidates(
        roomID: String,
        role: ReachMediaRole
    ) -> AsyncThrowingStream<ReachIceCandidate, Error>
}
