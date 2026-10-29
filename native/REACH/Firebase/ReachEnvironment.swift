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
    case productionLocked

    var errorDescription: String? {
        switch self {
        case .projectMismatch:
            return "Firebase project does not match the selected REACH environment."
        case .productionLocked:
            return "Native production writes are locked until migration is explicitly approved."
        }
    }
}
