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

        try ReachEnvironmentGuard.validateNativeConfiguration(
            projectID: options.projectID,
            configuredBundleID: options.bundleID,
            runningBundleID: Bundle.main.bundleIdentifier
        )

        FirebaseApp.configure(options: options)
        try validateConfiguredProject()
    }

    private static func validateConfiguredProject() throws {
        guard let options = FirebaseApp.app()?.options else {
            throw FirebaseBootstrapError.missingConfiguration
        }

        try ReachEnvironmentGuard.validateNativeConfiguration(
            projectID: options.projectID,
            configuredBundleID: options.bundleID,
            runningBundleID: Bundle.main.bundleIdentifier
        )
    }
}

enum FirebaseBootstrapError: LocalizedError, Equatable {
    case missingConfiguration

    var errorDescription: String? {
        "Staging Firebase configuration is not installed on this build."
    }
}
