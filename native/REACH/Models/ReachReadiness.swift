import Foundation

struct ReachReadiness: Equatable {
    let authenticated: Bool
    let partnershipLocked: Bool
    let partnershipAuthorized: Bool
    let mediaReady: Bool

    var isReady: Bool {
        authenticated && partnershipLocked && partnershipAuthorized && mediaReady
    }

    var blockingReason: String? {
        if !authenticated { return "Securing this device…" }
        if !partnershipLocked { return "Pair this device with your partner." }
        if !partnershipAuthorized { return "This partnership needs authorization." }
        if !mediaReady { return "Camera and microphone access are needed." }
        return nil
    }
}
