import XCTest
@testable import REACH

final class SessionContinuityPolicyTests: XCTestCase {
    func testForegroundRecoveringVerifiesTransport() {
        XCTAssertEqual(
            SessionContinuityPolicy.action(lifecycle: .active, sessionPhase: .recovering),
            .verifyTransport
        )
    }

    func testForegroundLiveRestoresPresentation() {
        XCTAssertEqual(
            SessionContinuityPolicy.action(lifecycle: .active, sessionPhase: .live),
            .restorePresentation
        )
    }

    func testBackgroundConnectingMarksInterrupted() {
        XCTAssertEqual(
            SessionContinuityPolicy.action(lifecycle: .background, sessionPhase: .connecting),
            .markInterrupted
        )
    }

    func testNoSessionDoesNothing() {
        XCTAssertEqual(
            SessionContinuityPolicy.action(lifecycle: .active, sessionPhase: nil),
            .none
        )
    }
}
