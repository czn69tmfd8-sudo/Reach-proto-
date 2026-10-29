import XCTest
@testable import REACH

final class ReachReconnectPolicyTests: XCTestCase {
    func testReconnectUsesBoundedBackoff() {
        XCTAssertEqual(ReachReconnectPolicy.decision(attempt: 0, appIsActive: true), .wait(1))
        XCTAssertEqual(ReachReconnectPolicy.decision(attempt: 1, appIsActive: true), .wait(2))
        XCTAssertEqual(ReachReconnectPolicy.decision(attempt: 2, appIsActive: true), .wait(4))
        XCTAssertEqual(ReachReconnectPolicy.decision(attempt: 3, appIsActive: true), .wait(8))
        XCTAssertEqual(ReachReconnectPolicy.decision(attempt: 4, appIsActive: true), .fail)
    }

    func testBackgroundDoesNotBlindlyReconnect() {
        XCTAssertEqual(
            ReachReconnectPolicy.decision(attempt: 0, appIsActive: false),
            .verifyTransport
        )
    }
}
