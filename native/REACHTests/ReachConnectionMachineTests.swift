import XCTest
@testable import REACH

final class ReachConnectionMachineTests: XCTestCase {
    private let session = ReachSession(
        id: "session",
        partnershipID: "pair",
        openedBy: "partner",
        openedAt: Date(timeIntervalSince1970: 0),
        phase: .open
    )

    func testTakingOpenHandMovesToConnecting() {
        let next = ReachConnectionMachine.reduce(session, event: .connectionStarted)
        XCTAssertEqual(next?.phase, .connecting)
    }

    func testMediaConnectionMovesToLive() {
        var connecting = session
        connecting.phase = .connecting
        let next = ReachConnectionMachine.reduce(connecting, event: .mediaConnected)
        XCTAssertEqual(next?.phase, .live)
    }

    func testInterruptionAndRecovery() {
        var live = session
        live.phase = .live
        let interrupted = ReachConnectionMachine.reduce(live, event: .connectionInterrupted)
        XCTAssertEqual(interrupted?.phase, .recovering)
        let recovered = ReachConnectionMachine.reduce(interrupted, event: .connectionRecovered)
        XCTAssertEqual(recovered?.phase, .live)
    }

    func testEndingClearsSession() {
        XCTAssertNil(ReachConnectionMachine.reduce(session, event: .ended))
    }

    func testFailurePreservesReason() {
        let failed = ReachConnectionMachine.reduce(session, event: .failed("network"))
        XCTAssertEqual(failed?.phase, .failed("network"))
    }
}
