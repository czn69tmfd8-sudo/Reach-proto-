import AVFoundation
import Foundation

final class NativeCameraCapture: ReachCameraCapture {
    private let session = AVCaptureSession()
    private var input: AVCaptureDeviceInput?
    private let queue = DispatchQueue(label: "reach.camera.capture")

    private(set) var isRunning = false

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

        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                self.session.beginConfiguration()
                defer { self.session.commitConfiguration() }

                if let old = self.input {
                    self.session.removeInput(old)
                }

                guard self.session.canAddInput(newInput) else {
                    continuation.resume(throwing: ReachCameraCaptureError.configurationFailed)
                    return
                }

                self.session.addInput(newInput)
                self.input = newInput
                continuation.resume()
            }
        }
    }

    func start() throws {
        guard input != nil else { throw ReachCameraCaptureError.configurationFailed }
        queue.async {
            if !self.session.isRunning {
                self.session.startRunning()
            }
            self.isRunning = self.session.isRunning
        }
    }

    func stop() {
        queue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
            self.isRunning = false
        }
    }

    func switchCamera() async throws {
        let current = input?.device.position
        let next: ReachCameraPosition = current == .front ? .back : .front
        try await prepare(position: next)
    }
}
