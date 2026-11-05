import XCTest
@preconcurrency import WebRTC
@testable import REACH

/// Real SDK negotiation without camera permission, Firebase, or external network access.
/// This does not assert that media traveled between two physical devices.
@MainActor
final class WebRTCEngineTests: XCTestCase {
    func testTwoNativePeersNegotiateAudioVideoAndClose() async throws {
        RTCInitializeSSL()
        let factory = RTCPeerConnectionFactory(encoderFactory: RTCDefaultVideoEncoderFactory(), decoderFactory: RTCDefaultVideoDecoderFactory())
        let configuration = RTCConfiguration()
        configuration.sdpSemantics = .unifiedPlan
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let opener = try XCTUnwrap(factory.peerConnection(with: configuration, constraints: constraints, delegate: nil))
        let joiner = try XCTUnwrap(factory.peerConnection(with: configuration, constraints: constraints, delegate: nil))
        defer { opener.close(); joiner.close() }
        for (index, peer) in [opener, joiner].enumerated() {
            let audio = factory.audioTrack(with: factory.audioSource(with: constraints), trackId: "audio-\(index)")
            let video = factory.videoTrack(with: factory.videoSource(), trackId: "video-\(index)")
            XCTAssertNotNil(peer.add(audio, streamIds: ["reach"]))
            XCTAssertNotNil(peer.add(video, streamIds: ["reach"]))
        }
        let offer = try await makeDescription(peer: opener, offer: true)
        XCTAssertTrue(offer.sdp.contains("m=audio"))
        XCTAssertTrue(offer.sdp.contains("m=video"))
        XCTAssertTrue(offer.sdp.contains("a=fingerprint:sha-256"))
        try await apply(offer, peer: opener, local: true)
        try await apply(offer, peer: joiner, local: false)
        let answer = try await makeDescription(peer: joiner, offer: false)
        try await apply(answer, peer: joiner, local: true)
        try await apply(answer, peer: opener, local: false)
        XCTAssertEqual(opener.signalingState, .stable)
        XCTAssertEqual(joiner.signalingState, .stable)
        opener.close(); joiner.close()
        XCTAssertEqual(opener.signalingState, .closed)
        XCTAssertEqual(joiner.signalingState, .closed)
    }

    private func makeDescription(peer: RTCPeerConnection, offer: Bool) async throws -> ReachSessionDescription {
        try await withCheckedThrowingContinuation { continuation in
            let completion: (RTCSessionDescription?, Error?) -> Void = { description, error in
                if let error { continuation.resume(throwing: error) }
                else if let description {
                    continuation.resume(returning: ReachSessionDescription(kind: offer ? .offer : .answer, sdp: description.sdp))
                } else { continuation.resume(throwing: PeerError.creation) }
            }
            let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
            if offer { peer.offer(for: constraints, completionHandler: completion) }
            else { peer.answer(for: constraints, completionHandler: completion) }
        }
    }

    private func apply(_ description: ReachSessionDescription, peer: RTCPeerConnection, local: Bool) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let value = RTCSessionDescription(type: description.kind == .offer ? .offer : .answer, sdp: description.sdp)
            let completion: (Error?) -> Void = { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
            if local { peer.setLocalDescription(value, completionHandler: completion) }
            else { peer.setRemoteDescription(value, completionHandler: completion) }
        }
    }
}
