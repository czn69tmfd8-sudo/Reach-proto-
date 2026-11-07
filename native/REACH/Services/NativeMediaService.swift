import AVFoundation
import Foundation

/// Native media boundary. Camera capture and WebRTC transport are intentionally
/// separate so the formal web test can inform the final transport implementation.
actor NativeMediaService {
    private let permissions = NativePermissionService()
    private let audio = NativeAudioSessionController()

    func prepare() async throws -> MediaPermissionState {
        let permission = await permissions.requestCameraAndMicrophone()
        guard permission == .granted else { return .denied }
        try await audio.configureForReach()
        return .granted
    }

    func stop() async {
        await audio.deactivate()
    }
}
