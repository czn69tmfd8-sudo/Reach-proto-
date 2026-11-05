import AVFoundation
import SwiftUI
@preconcurrency import WebRTC

/// All ownership and callbacks are serialized on the main actor. WebRTC owns its worker threads.
@MainActor
final class NativeWebRTCPeer: NSObject, ObservableObject {
    @Published private(set) var localVideo: RTCVideoTrack?
    @Published private(set) var remoteVideo: RTCVideoTrack?
    var onCandidate: ((ReachIceCandidate) -> Void)?
    var onState: ((String) -> Void)?
    private var peer: RTCPeerConnection?
    private var camera: RTCCameraVideoCapturer?
    private var audio: RTCAudioTrack?
    private var closed = false
    private static let factory: RTCPeerConnectionFactory = {
        RTCInitializeSSL()
        return RTCPeerConnectionFactory(encoderFactory: RTCDefaultVideoEncoderFactory(), decoderFactory: RTCDefaultVideoDecoderFactory())
    }()

    func prepare() async throws {
        guard !closed, peer == nil else { throw CancellationError() }
        guard await NativePermissionService().requestCameraAndMicrophone() == .granted else { throw PeerError.permission }
        try checkOpen()
        let config = RTCConfiguration()
        config.sdpSemantics = .unifiedPlan
        // Direct/STUN prototype. TURN credentials must be provisioned before promising cellular reliability.
        config.iceServers = [RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])]
        config.continualGatheringPolicy = .gatherContinually
        guard let connection = Self.factory.peerConnection(with: config, constraints: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil), delegate: self) else { throw PeerError.creation }
        peer = connection
        try configureAudio()
        let track = Self.factory.audioTrack(with: Self.factory.audioSource(with: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)), trackId: "reach-audio")
        audio = track
        connection.add(track, streamIds: ["reach"])
        let source = Self.factory.videoSource()
        let video = Self.factory.videoTrack(with: source, trackId: "reach-video")
        localVideo = video
        connection.add(video, streamIds: ["reach"])
        #if !targetEnvironment(simulator)
        let capturer = RTCCameraVideoCapturer(delegate: source)
        camera = capturer
        guard let device = RTCCameraVideoCapturer.captureDevices().first(where: { $0.position == .front }) ?? RTCCameraVideoCapturer.captureDevices().first,
              let format = RTCCameraVideoCapturer.supportedFormats(for: device).min(by: {
                  abs(CMVideoFormatDescriptionGetDimensions($0.formatDescription).width - 640) < abs(CMVideoFormatDescriptionGetDimensions($1.formatDescription).width - 640)
              }), let maxFPS = format.videoSupportedFrameRateRanges.map(\.maxFrameRate).max() else { throw PeerError.camera }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            capturer.startCapture(with: device, format: format, fps: min(30, Int(maxFPS))) { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
        if closed { capturer.stopCapture(); throw CancellationError() }
        #endif
    }

    private func configureAudio() throws {
        let session = RTCAudioSession.sharedInstance()
        session.lockForConfiguration()
        defer { session.unlockForConfiguration() }
        try session.setCategory(AVAudioSession.Category.playAndRecord, with: [.defaultToSpeaker, .allowBluetoothHFP])
        try session.setMode(AVAudioSession.Mode.videoChat)
    }

    func makeDescription(_ kind: ReachSessionDescription.Kind) async throws -> ReachSessionDescription {
        try checkOpen()
        guard let peer else { throw PeerError.creation }
        let description: ReachSessionDescription = try await withCheckedThrowingContinuation { continuation in
            let callback: (RTCSessionDescription?, Error?) -> Void = { result, error in
                if let error { continuation.resume(throwing: error) }
                else if let result { continuation.resume(returning: ReachSessionDescription(kind: kind, sdp: result.sdp)) }
                else { continuation.resume(throwing: PeerError.creation) }
            }
            let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
            if kind == .offer { peer.offer(for: constraints, completionHandler: callback) }
            else { peer.answer(for: constraints, completionHandler: callback) }
        }
        try checkOpen()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            peer.setLocalDescription(RTCSessionDescription(type: kind == .offer ? .offer : .answer, sdp: description.sdp)) { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
        try checkOpen()
        return description
    }

    func apply(_ description: ReachSessionDescription) async throws {
        try checkOpen()
        guard let peer else { throw PeerError.creation }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            peer.setRemoteDescription(RTCSessionDescription(type: description.kind == .offer ? .offer : .answer, sdp: description.sdp)) { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
        try checkOpen()
        remoteVideo = peer.transceivers.first(where: { $0.mediaType == .video })?.receiver.track as? RTCVideoTrack
    }

    func add(_ candidate: ReachIceCandidate) async throws {
        try checkOpen()
        guard let peer else { throw PeerError.creation }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            peer.add(RTCIceCandidate(sdp: candidate.sdp, sdpMLineIndex: candidate.sdpMLineIndex, sdpMid: candidate.sdpMid)) { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
        try checkOpen()
    }

    func setMuted(_ muted: Bool) { audio?.isEnabled = !muted }
    func setCameraEnabled(_ enabled: Bool) { localVideo?.isEnabled = enabled }
    func close() {
        guard !closed else { return }
        closed = true
        onCandidate = nil; onState = nil
        audio?.isEnabled = false; localVideo?.isEnabled = false
        camera?.stopCapture(); camera = nil
        peer?.delegate = nil; peer?.close(); peer = nil
        audio = nil; localVideo = nil; remoteVideo = nil
    }
    private func checkOpen() throws { if closed || Task.isCancelled { throw CancellationError() } }
}

extension NativeWebRTCPeer: RTCPeerConnectionDelegate {
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        let value = ReachIceCandidate(sdp: candidate.sdp, sdpMid: candidate.sdpMid, sdpMLineIndex: candidate.sdpMLineIndex)
        Task { @MainActor [weak self] in guard let self, !self.closed else { return }; self.onCandidate?(value) }
    }
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCPeerConnectionState) {
        let raw = newState.rawValue
        Task { @MainActor [weak self] in
            guard let self, !self.closed else { return }
            switch RTCPeerConnectionState(rawValue: raw) {
            case .connected: self.onState?("Media transport connected")
            case .disconnected: self.onState?("Media transport interrupted")
            case .failed: self.onState?("Media transport failed — end and retry")
            case .closed: self.onState?("Media transport closed")
            default: self.onState?("Connecting media transport…")
            }
        }
    }
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    nonisolated func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
}

enum PeerError: LocalizedError {
    case permission, creation, camera
    var errorDescription: String? {
        switch self {
        case .permission: return "Enable camera and microphone access in Settings to call."
        case .creation: return "WebRTC could not prepare the peer connection."
        case .camera: return "No camera capture format is available."
        }
    }
}

struct WebRTCVideoView: UIViewRepresentable {
    let track: RTCVideoTrack?
    final class Coordinator { var track: RTCVideoTrack? }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> RTCMTLVideoView {
        let view = RTCMTLVideoView(frame: .zero)
        view.videoContentMode = .scaleAspectFit
        return view
    }
    func updateUIView(_ view: RTCMTLVideoView, context: Context) {
        guard context.coordinator.track !== track else { return }
        context.coordinator.track?.remove(view)
        track?.add(view)
        context.coordinator.track = track
    }
    static func dismantleUIView(_ view: RTCMTLVideoView, coordinator: Coordinator) { coordinator.track?.remove(view) }
}
