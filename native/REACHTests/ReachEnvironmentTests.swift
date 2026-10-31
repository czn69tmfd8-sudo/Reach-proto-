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
}
