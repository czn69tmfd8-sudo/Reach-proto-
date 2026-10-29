import AVFoundation
import Foundation

enum ReachCameraPosition: Equatable {
    case front
    case back
}

struct ReachCameraFormat: Equatable {
    let width: Int32
    let height: Int32
    let framesPerSecond: Int
}

protocol ReachCameraCapture: AnyObject {
    var isRunning: Bool { get }
    func prepare(position: ReachCameraPosition) async throws
    func start() throws
    func stop()
    func switchCamera() async throws
}

enum ReachCameraCaptureError: LocalizedError, Equatable {
    case permissionDenied
    case cameraUnavailable
    case configurationFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Camera access is required to start a REACH video connection."
        case .cameraUnavailable:
            return "No compatible camera is available."
        case .configurationFailed:
            return "REACH could not configure the camera."
        }
    }
}
