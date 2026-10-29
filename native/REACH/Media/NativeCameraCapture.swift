import AVFoundation
import Foundation

/// Camera capture is main-actor isolated. This keeps mutable capture state out of
/// Swift 6 cross-actor closures while AVCaptureSession itself still performs its
/// blocking start/stop work on a dedicated queue.
@MainActor
final class NativeCameraCapture: ReachCameraCapture {
    private let session = AVCaptureSession()
    private var input: AVCaptureDeviceInput?
    private var running = false
    private let queue = DispatchQueue(label: "reach.camera.capture")

    var isRunning: Bool { running }

    func prepare(position: ReachCameraPosition = .front) async throws {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        guard granted else { throw ReachCameraCaptureError.permissionDenied }

        let avPosition: AVCaptureDevice.Position = position == .front ? .front : .back
        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: avPosition
        ) else {
            throw ReachCameraCaptureError.cameraUnavailable
        }

        let newInput: AVCaptureDeviceInput
        do {
            newInput = try AVCaptureDeviceInput(device: device)
        } catch {
            throw ReachCameraCaptureError.configurationFailed
        }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        if let old = input {
            session.removeInput(old)
        }

        guard session.canAddInput(newInput) else {
            throw ReachCameraCaptureError.configurationFailed
        }

        session.addInput(newInput)
        input = newInput
    }

    func start() throws {
        guard input != nil else { throw ReachCameraCaptureError.configurationFailed }
        guard !running else { return }

        let captureSession = session
        queue.async {
            if !captureSession.isRunning {
                captureSession.startRunning()
            }
        }
        running = true
    }

    func stop() {
        guard running else { return }
        let captureSession = session
        queue.async {
            if captureSession.isRunning {
                captureSession.stopRunning()
            }
        }
        running = false
    }

    func switchCamera() async throws {
        let current = input?.device.position
        let next: ReachCameraPosition = current == .front ? .back : .front
        try await prepare(position: next)
    }
}
