import XCTest
@testable import REACH

final class ReachTransportWatchdogTests: XCTestCase {
    func testWaitingForPartnerDoesNotStartDeadline() {
        var policy = ReachTransportWatchdog()
        XCTAssertNil(policy.deadlineID)
        XCTAssertEqual(policy.receive(.disconnected), .none)
    }
    func testNegotiationIsBoundedAndRepeatedCallbacksDoNotExtendIt() {
        var policy = ReachTransportWatchdog()
        guard case .startDeadline(let id, let seconds) = policy.receive(.negotiationStarted) else { return XCTFail("Missing deadline") }
        XCTAssertEqual(seconds, 45)
        XCTAssertEqual(policy.receive(.negotiationStarted), .none)
        XCTAssertEqual(policy.deadlineExpired(id), .stop)
        XCTAssertTrue(policy.finished)
    }
    func testConnectedCancelsNegotiationAndLateTimeoutCannotEndCall() {
        var policy = ReachTransportWatchdog()
        guard case .startDeadline(let id, _) = policy.receive(.negotiationStarted) else { return XCTFail("Missing deadline") }
        XCTAssertEqual(policy.receive(.connected), .cancelDeadline)
        XCTAssertEqual(policy.deadlineExpired(id), .none)
        XCTAssertFalse(policy.finished)
    }
    func testRecoveredTransportRejectsOldInterruptionDeadline() {
        var policy = ReachTransportWatchdog()
        _ = policy.receive(.connected)
        guard case .startDeadline(let old, let seconds) = policy.receive(.disconnected) else { return XCTFail("Missing deadline") }
        XCTAssertEqual(seconds, 20)
        XCTAssertEqual(policy.receive(.disconnected), .none)
        XCTAssertEqual(policy.receive(.connected), .cancelDeadline)
        guard case .startDeadline(let current, _) = policy.receive(.disconnected) else { return XCTFail("Missing new deadline") }
        XCTAssertNotEqual(old, current)
        XCTAssertEqual(policy.deadlineExpired(old), .none)
        XCTAssertEqual(policy.deadlineExpired(current), .stop)
    }
    func testFailureIsTerminalAndCannotReviveAfterLateConnectedEvent() {
        var policy = ReachTransportWatchdog()
        XCTAssertEqual(policy.receive(.failed), .stop)
        XCTAssertEqual(policy.receive(.connected), .none)
        XCTAssertEqual(policy.receive(.negotiationStarted), .none)
        XCTAssertTrue(policy.finished)
    }
    func testClosedStopsImmediatelyAndIgnoresStaleDeadline() {
        var policy = ReachTransportWatchdog()
        guard case .startDeadline(let id, _) = policy.receive(.negotiationStarted) else { return XCTFail("Missing deadline") }
        XCTAssertEqual(policy.receive(.closed), .stop)
        XCTAssertEqual(policy.deadlineExpired(id), .none)
        XCTAssertNil(policy.deadlineID)
    }
}
