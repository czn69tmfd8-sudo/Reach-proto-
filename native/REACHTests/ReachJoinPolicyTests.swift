import XCTest
@testable import REACH

final class ReachJoinPolicyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 100_000)
    private let pair = Partnership(
        id: "pair",
        localMemberID: "byron",
        partnerMemberID: "aaron",
        partnerDisplayName: "Aaron",
        isAuthorized: true
    )

    func testPartnerFreshOpenHandCanBeTaken() {
        XCTAssertEqual(
            ReachJoinPolicy.decide(
                session: ReachSession(
                    id: "s",
                    partnershipID: "pair",
                    openedBy: "aaron",
                    openedAt: now.addingTimeInterval(-60),
                    phase: .open
                ),
                partnership: pair,
                now: now
            ),
            .allowed
        )
    }

    func testOwnHandCannotBeTaken() {
        XCTAssertEqual(
            ReachJoinPolicy.decide(
                session: ReachSession(
                    id: "s",
                    partnershipID: "pair",
                    openedBy: "byron",
                    openedAt: now.addingTimeInterval(-60),
                    phase: .open
                ),
                partnership: pair,
                now: now
            ),
            .ownHand
        )
    }

    func testStaleHandExpires() {
        XCTAssertEqual(
            ReachJoinPolicy.decide(
                session: ReachSession(
                    id: "s",
                    partnershipID: "pair",
                    openedBy: "aaron",
                    openedAt: now.addingTimeInterval(-(13 * 60 * 60)),
                    phase: .open
                ),
                partnership: pair,
                now: now
            ),
            .expired
        )
    }

    func testWrongPairCannotBeJoined() {
        XCTAssertEqual(
            ReachJoinPolicy.decide(
                session: ReachSession(
                    id: "s",
                    partnershipID: "other-pair",
                    openedBy: "aaron",
                    openedAt: now,
                    phase: .open
                ),
                partnership: pair,
                now: now
            ),
            .wrongPartnership
        )
    }
}
