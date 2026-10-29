import XCTest
@testable import REACH

final class ReachTransportStateTests: XCTestCase {
    func testSignalingDoesNotMeanMediaConnected() {
        let runtime = ReachRuntimeState(
            signaling: .complete,
            media: .connecting
        )
        XCTAssertFalse(runtime.isActuallyConnected)
        XCTAssertTrue(runtime.isStillNegotiating)
    }

    func testOnlyMediaConnectedCountsAsConnected() {
        let runtime = ReachRuntimeState(
            signaling: .answerObserved,
            media: .connected
        )
        XCTAssertTrue(runtime.isActuallyConnected)
    }
}
