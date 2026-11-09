import XCTest
@testable import REACH

final class PairSessionInterpreterTests: XCTestCase {
    private let partnership = Partnership(
        id: "ABC123",
        localMemberID: "byron",
        partnerMemberID: "aaron",
        partnerDisplayName: "Aaron",
        isAuthorized: true
    )

    func testNoActiveRoomMeansNoOpenHand() {
        let pair = PairRecord(
            hostUid: "byron",
            partnerUid: "aaron",
            revoked: false,
            activeRoom: nil,
            openedBy: nil
        )
        XCTAssertEqual(
            PairSessionInterpreter.presentation(pair: pair, partnership: partnership),
            .none
        )
    }

    func testLocalOpenIsMine() {
        let pair = PairRecord(
            hostUid: "byron",
            partnerUid: "aaron",
            revoked: false,
            activeRoom: "room-1",
            openedBy: "byron"
        )
        XCTAssertEqual(
            PairSessionInterpreter.presentation(pair: pair, partnership: partnership),
            .myHandOpen(roomID: "room-1")
        )
    }

    func testPartnerOpenIsPartnerHand() {
        let pair = PairRecord(
            hostUid: "byron",
            partnerUid: "aaron",
            revoked: false,
            activeRoom: "room-1",
            openedBy: "aaron"
        )
        XCTAssertEqual(
            PairSessionInterpreter.presentation(pair: pair, partnership: partnership),
            .partnerHandOpen(roomID: "room-1")
        )
    }

    func testUnknownOpenedByIsInvalid() {
        let pair = PairRecord(
            hostUid: "byron",
            partnerUid: "aaron",
            revoked: false,
            activeRoom: "room-1",
            openedBy: "stranger"
        )
        XCTAssertEqual(
            PairSessionInterpreter.presentation(pair: pair, partnership: partnership),
            .invalid
        )
    }
}
