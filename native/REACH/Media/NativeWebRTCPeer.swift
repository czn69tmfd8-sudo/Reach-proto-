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
    var onTransportEvent: ((ReachTransportWatchdog.Event) -> Void)?
    private var peer: RTCPeerConnection?
    private var camera: CameraCaptureLifetime?
    private var audio: RTCAudioTrack?
    private let controls = ReachMediaControls()
    private var closed = false
    private var preparing = false


    func prepare() async throws {
        guard !closed, !preparing, peer == nil else { throw CancellationError() }
        preparing = true
        var prepared = false
        defer {
            preparing = false
            if !prepared { close() }
        }
        guard await NativePermissionService().requestCameraAndMicrophone() == .granted else { throw PeerError.permission }
        try checkOpen()
        let factory = try await WebRTCFactoryProvider.shared.get().factory
        try checkOpen()
        let config = RTCConfiguration()
        config.sdpSemantics = .unifiedPlan
        // Direct/STUN prototype. TURN credentials must be provisioned before promising cellular reliability.
        config.iceServers = [RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])]
        config.continualGatheringPolicy = .gatherContinually
        guard let connection = factory.peerConnection(with: config, constraints: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil), delegate: self) else { throw PeerError.creation }
        peer = connection
        try configureAudio()
        let track = factory.audioTrack(with: factory.audioSource(with: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)), trackId: "reach-audio")
        audio = track
        controls.bindMicrophone { [weak track] in track?.isEnabled = $0 }
        connection.add(track, streamIds: ["reach"])
        let source = factory.videoSource()
        let video = factory.videoTrack(with: source, trackId: "reach-video")
        localVideo = video
        controls.bindCamera { [weak video] in video?.isEnabled = $0 }
        connection.add(video, streamIds: ["reach"])
        #if !targetEnvironment(simulator)
        let capturer = RTCCameraVideoCapturer(delegate: source)
        guard let device = RTCCameraVideoCapturer.captureDevices().first(where: { $0.position == .front }) ?? RTCCameraVideoCapturer.captureDevices().first,
              let format = RTCCameraVideoCapturer.supportedFormats(for: device).min(by: {
                  abs(CMVideoFormatDescriptionGetDimensions($0.formatDescription).width - 640) < abs(CMVideoFormatDescriptionGetDimensions($1.formatDescription).width - 640)
              }), let maxFPS = format.videoSupportedFrameRateRanges.map(\.maxFrameRate).max() else { throw PeerError.camera }
        let capture = CameraCaptureLifetime(driver: WebRTCCameraCaptureDriver(
            capturer: capturer, device: device, format: format, fps: min(30, Int(maxFPS))))
        camera = capture
        do {
            try await capture.start()
            try checkOpen()
        } catch {
            // Cancellation and a close during startup cannot leave audio/video alive.
            close()
            throw error
        }
        #endif
        prepared = true
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
            let deadline = CallbackDeadline(continuation, operation: "create \(kind.rawValue)")
            let callback: @Sendable (RTCSessionDescription?, Error?) -> Void = { result, error in
                if let error { deadline.resolve(.failure(error)) }
                else if let result { deadline.resolve(.success(ReachSessionDescription(kind: kind, sdp: result.sdp))) }
                else { deadline.resolve(.failure(PeerError.creation)) }
            }
            let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
            if kind == .offer { peer.offer(for: constraints, completionHandler: callback) }
            else { peer.answer(for: constraints, completionHandler: callback) }
        }
        try checkOpen()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let deadline = CallbackDeadline(continuation, operation: "set local SDP")
            peer.setLocalDescription(RTCSessionDescription(type: kind == .offer ? .offer : .answer, sdp: description.sdp)) { error in
                if let error { deadline.resolve(.failure(error)) } else { deadline.resolve(.success(())) }
            }
        }
        try checkOpen()
        return description
    }

    func apply(_ description: ReachSessionDescription) async throws {
        try checkOpen()
        guard let peer else { throw PeerError.creation }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let deadline = CallbackDeadline(continuation, operation: "set remote SDP")
            peer.setRemoteDescription(RTCSessionDescription(type: description.kind == .offer ? .offer : .answer, sdp: description.sdp)) { error in
                if let error { deadline.resolve(.failure(error)) } else { deadline.resolve(.success(())) }
            }
        }
        try checkOpen()
        remoteVideo = peer.transceivers.first(where: { $0.mediaType == .video })?.receiver.track as? RTCVideoTrack
    }

    func add(_ candidate: ReachIceCandidate) async throws {
        try checkOpen()
        guard let peer else { throw PeerError.creation }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let deadline = CallbackDeadline(continuation, operation: "add remote ICE")
            peer.add(RTCIceCandidate(sdp: candidate.sdp, sdpMLineIndex: candidate.sdpMLineIndex, sdpMid: candidate.sdpMid)) { error in
                if let error { deadline.resolve(.failure(error)) } else { deadline.resolve(.success(())) }
            }
        }
        try checkOpen()
    }

    func setMuted(_ muted: Bool) { controls.setMuted(muted) }
    func setCameraEnabled(_ enabled: Bool) { controls.setCameraEnabled(enabled) }
    func close() {
        guard !closed else { return }
        closed = true
        onCandidate = nil; onState = nil; onTransportEvent = nil
        controls.close()
        camera?.close(); camera = nil
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
            case .connected:
                self.onState?("Media transport connected")
                self.onTransportEvent?(.connected)
            case .disconnected:
                self.onState?("Media transport interrupted")
                self.onTransportEvent?(.disconnected)
            case .failed:
                self.onState?("Media transport failed — end and retry")
                self.onTransportEvent?(.failed)
            case .closed:
                self.onState?("Media transport closed")
                self.onTransportEvent?(.closed)
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
