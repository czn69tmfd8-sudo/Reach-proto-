import Foundation
@preconcurrency import WebRTC

/// WebRTC synchronizes factory operations internally. This immutable handle is the
/// only transfer of the SDK factory from its initialization queue to UI ownership.
struct WebRTCFactoryHandle: @unchecked Sendable {
    let factory: RTCPeerConnectionFactory
}

final class WebRTCFactoryProvider: @unchecked Sendable {
    static let shared = WebRTCFactoryProvider()
    private let queue = DispatchQueue(label: "com.reachprototype.webrtc.factory")
    // Accessed exclusively on queue, including initialization.
    private var handle: WebRTCFactoryHandle?

    func get() async throws -> WebRTCFactoryHandle {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<WebRTCFactoryHandle, Error>) in
            let deadline = CallbackDeadline(continuation, operation: "initialize audio/video factory", seconds: 20)
            queue.async {
                if let handle = self.handle { deadline.resolve(.success(handle)); return }
                // Default ADM performs synchronous system audio initialization. Do not
                // block MainActor while CoreAudio may need the application's run loop.
                RTCInitializeSSL()
                let handle = WebRTCFactoryHandle(factory: RTCPeerConnectionFactory(
                    encoderFactory: RTCDefaultVideoEncoderFactory(), decoderFactory: RTCDefaultVideoDecoderFactory()
                ))
                self.handle = handle
                deadline.resolve(.success(handle))
            }
        }
    }
}
