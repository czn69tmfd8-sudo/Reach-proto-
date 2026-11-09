#if !targetEnvironment(simulator)
import AVFoundation
@preconcurrency import WebRTC

@MainActor
final class WebRTCCameraCaptureDriver: CameraCaptureDriver {
    private let capturer: RTCCameraVideoCapturer
    private let device: AVCaptureDevice
    private let format: AVCaptureDevice.Format
    private let fps: Int

    init(capturer: RTCCameraVideoCapturer, device: AVCaptureDevice, format: AVCaptureDevice.Format, fps: Int) {
        self.capturer = capturer
        self.device = device
        self.format = format
        self.fps = fps
    }

    func start(completion: @escaping @Sendable (Error?) -> Void) {
        capturer.startCapture(with: device, format: format, fps: fps) { error in completion(error) }
    }

    func stop(completion: @escaping @Sendable () -> Void) {
        // Spell the callback overload explicitly. A bare stopCapture() in an async
        // context selects the Swift-concurrency imported overload instead.
        capturer.stopCapture(completionHandler: completion)
    }
}
#endif
