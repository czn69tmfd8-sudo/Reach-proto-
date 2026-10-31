import AVFoundation
import Foundation

struct NativePermissionService {
    func requestCameraAndMicrophone() async -> MediaPermissionState {
        async let camera = request(.video)
        async let microphone = request(.audio)
        return await (camera && microphone) ? .granted : .denied
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
