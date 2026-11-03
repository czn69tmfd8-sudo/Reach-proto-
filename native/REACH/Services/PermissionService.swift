import AVFoundation
import Foundation

struct NativePermissionService {
    func requestCameraAndMicrophone() async -> MediaPermissionState {
        async let cameraRequest = request(.video)
        async let microphoneRequest = request(.audio)

        let cameraGranted = await cameraRequest
        let microphoneGranted = await microphoneRequest
        return cameraGranted && microphoneGranted ? .granted : .denied
    }

    private func request(_ type: AVMediaType) async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: type) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: type)
        default:
            return false
        }
    }
}
