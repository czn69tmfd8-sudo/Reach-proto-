import Foundation

enum ReachEnvironment: String, Codable, CaseIterable {
    case development
    case staging
    case production

    var firebaseProjectID: String? {
        switch self {
        case .development:
            return nil
        case .staging:
            return "reach-staging-a4745"
        case .production:
            return "reach-prototype-d70ef"
        }
    }

    var allowsWrites: Bool {
        switch self {
        case .development, .staging:
            return true
        case .production:
            return false
        }
    }
}

enum ReachEnvironmentGuard {
    static let nativeBundleID = "com.reachprototype.app"

    static func validateNativeConfiguration(projectID: String?, configuredBundleID: String?, runningBundleID: String?) throws {
        try validate(environment: .staging, configuredProjectID: projectID)
        guard configuredBundleID == nativeBundleID, runningBundleID == nativeBundleID else {
            throw ReachEnvironmentError.bundleMismatch
        }
    }

    static func validate(
        environment: ReachEnvironment,
        configuredProjectID: String?
    ) throws {
        guard environment.firebaseProjectID == configuredProjectID else {
            throw ReachEnvironmentError.projectMismatch
        }
        if environment == .production {
            throw ReachEnvironmentError.productionLocked
        }
    }
}

enum ReachEnvironmentError: LocalizedError, Equatable {
    case projectMismatch
    case bundleMismatch
    case productionLocked

    var errorDescription: String? {
        switch self {
        case .bundleMismatch:
            return "Firebase configuration does not match this native REACH app."
        case .projectMismatch:
            return "Firebase project does not match the selected REACH environment."
        case .productionLocked:
            return "Native production writes are locked until migration is explicitly approved."
        }
    }
}
