import XCTest
@preconcurrency import WebRTC
@testable import REACH

/// Real SDK negotiation without camera permission, Firebase, or external network access.
/// This does not assert that media traveled between two physical devices.
final class WebRTCEngineTests: XCTestCase {
    func testTwoNativePeersNegotiateAudioVideoAndClose() async throws {
        // Never initialize the default CoreAudio ADM in a headless simulator test.
        // This injected device affects hardware I/O only, not the WebRTC peer stack.
        print("WebRTC checkpoint: create factory with negotiation audio device")
        RTCInitializeSSL()
        let audioDevice = NegotiationAudioDevice()
        let factory = RTCPeerConnectionFactory(encoderFactory: RTCDefaultVideoEncoderFactory(), decoderFactory: RTCDefaultVideoDecoderFactory(), audioDevice: audioDevice)
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
        print("WebRTC checkpoint: create audio/video offer")
        let offer = try await makeDescription(peer: opener, offer: true)
        XCTAssertTrue(offer.sdp.contains("m=audio"))
        XCTAssertTrue(offer.sdp.contains("m=video"))
        XCTAssertTrue(offer.sdp.contains("a=fingerprint:sha-256"))
        try await apply(offer, peer: opener, local: true)
        try await apply(offer, peer: joiner, local: false)
        print("WebRTC checkpoint: create audio/video answer")
        let answer = try await makeDescription(peer: joiner, offer: false)
        try await apply(answer, peer: joiner, local: true)
        try await apply(answer, peer: opener, local: false)
        XCTAssertTrue(audioDevice.didInitialize, "The real WebRTC ADM must initialize the injected test audio device")
        XCTAssertEqual(opener.signalingState, .stable)
        XCTAssertEqual(joiner.signalingState, .stable)
        print("WebRTC checkpoint: close both negotiated peers")
        opener.close(); joiner.close()
        XCTAssertEqual(opener.signalingState, .closed)
        XCTAssertEqual(joiner.signalingState, .closed)
    }

    func testSetupPrivacyChoicesApplyToRealSDKTracks() async {
        await MainActor.run {
            RTCInitializeSSL()
            let factory = RTCPeerConnectionFactory(
                encoderFactory: RTCDefaultVideoEncoderFactory(),
                decoderFactory: RTCDefaultVideoDecoderFactory(),
                audioDevice: NegotiationAudioDevice())
            let audio = factory.audioTrack(with: factory.audioSource(with:
                RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)), trackId: "privacy-audio")
            let video = factory.videoTrack(with: factory.videoSource(), trackId: "privacy-video")
            let controls = ReachMediaControls()
            controls.setMuted(true); controls.setCameraEnabled(false)
            controls.bindMicrophone { audio.isEnabled = $0 }
            controls.bindCamera { video.isEnabled = $0 }
            XCTAssertFalse(audio.isEnabled); XCTAssertFalse(video.isEnabled)
            controls.setMuted(false); controls.setCameraEnabled(true)
            XCTAssertTrue(audio.isEnabled); XCTAssertTrue(video.isEnabled)
            controls.close()
            controls.setMuted(false); controls.setCameraEnabled(true)
            XCTAssertFalse(audio.isEnabled); XCTAssertFalse(video.isEnabled)
        }
    }

    private func makeDescription(peer: RTCPeerConnection, offer: Bool) async throws -> ReachSessionDescription {
        try await withCheckedThrowingContinuation { continuation in
            let deadline = CallbackDeadline(continuation, operation: offer ? "test create offer" : "test create answer")
            let completion: @Sendable (RTCSessionDescription?, Error?) -> Void = { description, error in
                if let error { deadline.resolve(.failure(error)) }
                else if let description {
                    deadline.resolve(.success(ReachSessionDescription(kind: offer ? .offer : .answer, sdp: description.sdp)))
                } else { deadline.resolve(.failure(PeerError.creation)) }
            }
            let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
            if offer { peer.offer(for: constraints, completionHandler: completion) }
            else { peer.answer(for: constraints, completionHandler: completion) }
        }
    }

    private func apply(_ description: ReachSessionDescription, peer: RTCPeerConnection, local: Bool) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let deadline = CallbackDeadline(continuation, operation: local ? "test set local SDP" : "test set remote SDP")
            let value = RTCSessionDescription(type: description.kind == .offer ? .offer : .answer, sdp: description.sdp)
            let completion: @Sendable (Error?) -> Void = { error in
                if let error { deadline.resolve(.failure(error)) } else { deadline.resolve(.success(())) }
            }
            if local { peer.setLocalDescription(value, completionHandler: completion) }
            else { peer.setRemoteDescription(value, completionHandler: completion) }
        }
    }
}
