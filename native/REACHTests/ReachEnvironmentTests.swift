import XCTest
@testable import REACH

final class ReachEnvironmentTests: XCTestCase {
    func testStagingAcceptsOnlyStagingProject() {
        XCTAssertNoThrow(
            try ReachEnvironmentGuard.validate(
                environment: .staging,
                configuredProjectID: "reach-staging-a4745"
            )
        )

        XCTAssertThrowsError(
            try ReachEnvironmentGuard.validate(
                environment: .staging,
                configuredProjectID: "reach-prototype-d70ef"
            )
        )
    }

    func testProductionRemainsLocked() {
        XCTAssertThrowsError(
            try ReachEnvironmentGuard.validate(
                environment: .production,
                configuredProjectID: "reach-prototype-d70ef"
            )
        ) { error in
            XCTAssertEqual(error as? ReachEnvironmentError, .productionLocked)
        }
    }
    func testNativeConfigurationRequiresBothConfiguredAndRunningBundle() {
        XCTAssertNoThrow(try ReachEnvironmentGuard.validateNativeConfiguration(
            projectID: "reach-staging-a4745", configuredBundleID: "com.reachprototype.app", runningBundleID: "com.reachprototype.app"))
        for (configured, running) in [("other", "com.reachprototype.app"), ("com.reachprototype.app", "other"), (nil, "com.reachprototype.app"), ("com.reachprototype.app", nil)] as [(String?, String?)] {
            XCTAssertThrowsError(try ReachEnvironmentGuard.validateNativeConfiguration(
                projectID: "reach-staging-a4745", configuredBundleID: configured, runningBundleID: running))
        }
    }

    func testMatchingNativeBundleCannotAuthorizeProductionProject() {
        XCTAssertThrowsError(try ReachEnvironmentGuard.validateNativeConfiguration(
            projectID: "reach-prototype-d70ef", configuredBundleID: "com.reachprototype.app", runningBundleID: "com.reachprototype.app"))
    }
}
