import FirebaseCore
import Foundation

enum FirebaseBootstrap {
    static func configureStaging() throws {
        guard FirebaseApp.app() == nil else {
            try validateConfiguredProject()
            return
        }

        guard
            let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
            let options = FirebaseOptions(contentsOfFile: path)
        else {
            throw FirebaseBootstrapError.missingConfiguration
        }

        try ReachEnvironmentGuard.validate(
            environment: .staging,
            configuredProjectID: options.projectID
        )

        FirebaseApp.configure(options: options)
        try validateConfiguredProject()
    }

    private static func validateConfiguredProject() throws {
        guard let projectID = FirebaseApp.app()?.options.projectID else {
            throw FirebaseBootstrapError.missingConfiguration
        }

        try ReachEnvironmentGuard.validate(
            environment: .staging,
            configuredProjectID: projectID
        )
    }
}

enum FirebaseBootstrapError: LocalizedError, Equatable {
    case missingConfiguration

    var errorDescription: String? {
        "Staging Firebase configuration is not installed on this build."
    }
}
