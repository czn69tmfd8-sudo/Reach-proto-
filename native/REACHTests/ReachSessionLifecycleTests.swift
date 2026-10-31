import XCTest
@testable import REACH

final class ReachSessionLifecycleTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 500_000)
    private let pair = Partnership(
        id: "pair",
        localMemberID: "byron",
        partnerMemberID: "aaron",
        partnerDisplayName: "Aaron",
        isAuthorized: true
    )

    private func session(
        openedBy: String = "byron",
        age: TimeInterval = 60,
        phase: ReachSessionPhase = .open
    ) -> ReachSession {
        ReachSession(
            id: "room-1",
            partnershipID: "pair",
            openedBy: openedBy,
            openedAt: now.addingTimeInterval(-age),
            phase: phase
        )
    }

    func testDuplicateOpenReusesCurrentSession() {
        XCTAssertEqual(
            ReachSessionLifecycle.openingDecision(
                existing: session(),
                partnership: pair,
                now: now
            ),
            .reuse(session())
        )
    }

    func testPartnerOpenSessionBlocksSecondOpen() {
        XCTAssertEqual(
            ReachSessionLifecycle.openingDecision(
                existing: session(openedBy: "aaron"),
                partnership: pair,
                now: now
            ),
            .reject("Your partner already has an active REACH.")
        )
    }

    func testExpiredSessionCanBeReplaced() {
        XCTAssertEqual(
            ReachSessionLifecycle.openingDecision(
                existing: session(age: 13 * 60 * 60),
                partnership: pair,
                now: now
            ),
            .create
        )
    }

    func testCleanupCannotClearNewerRoom() {
        let token = ReachCleanupToken(partnershipID: "pair", sessionID: "old-room")
        XCTAssertFalse(
            ReachCleanupPolicy.shouldClearPairPointer(
                token: token,
                currentActiveRoom: "new-room"
            )
        )
    }

    func testCleanupCanClearItsOwnRoom() {
        let token = ReachCleanupToken(partnershipID: "pair", sessionID: "room-1")
        XCTAssertTrue(
            ReachCleanupPolicy.shouldClearPairPointer(
                token: token,
                currentActiveRoom: "room-1"
            )
        )
    }
}
