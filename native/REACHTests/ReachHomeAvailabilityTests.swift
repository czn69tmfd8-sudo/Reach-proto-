import XCTest
@testable import REACH

final class ReachHomeAvailabilityTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 10_000)
    private var partnership: Partnership {
        Partnership(id: "PAIR", localMemberID: "local", partnerMemberID: "partner", partnerDisplayName: "Partner", isAuthorized: true)
    }
    private func pair(room: String? = "room", opener: String? = "partner") -> PairRecord {
        PairRecord(hostUid: "local", partnerUid: "partner", revoked: false, activeRoom: room, openedBy: opener)
    }
    private func room(host: String = "partner", partner: String = "local", code: String = "PAIR", active: Bool = true, expiry: Double = 60) -> RoomRecord {
        RoomRecord(hostUid: host, partnerUid: partner, pairCode: code, createdAt: now,
                   expiresAt: now.addingTimeInterval(expiry), active: active, offer: nil, answer: nil)
    }
    func testNoHandActionsBeforeVerifiedPairing() {
        for hint in [ReachHomeAvailability.checking, .unpaired, .invitation, .unavailable] {
            XCTAssertFalse(hint.canOpen(at: now)); XCTAssertFalse(hint.canTake(at: now)); XCTAssertFalse(hint.paired(at: now))
        }
    }
    func testReadyPairCanOnlyOpenAndDisplayHintExpires() {
        let hint = ReachHomeAvailability.resolve(partnership: partnership, pair: pair(room: nil, opener: nil), room: nil, now: now)
        XCTAssertTrue(hint.canOpen(at: now)); XCTAssertFalse(hint.canTake(at: now))
        XCTAssertFalse(hint.canOpen(at: now.addingTimeInterval(15)))
        XCTAssertEqual(hint.title(at: now.addingTimeInterval(15)), "Checking availability")
    }
    func testPartnerHandRequiresCurrentMatchingRoom() {
        let hint = ReachHomeAvailability.resolve(partnership: partnership, pair: pair(), room: room(), now: now)
        XCTAssertTrue(hint.canTake(at: now)); XCTAssertFalse(hint.canOpen(at: now))
    }
    func testOwnHandCannotBeTakenOrReopened() {
        let hint = ReachHomeAvailability.resolve(partnership: partnership, pair: pair(opener: "local"), room: room(host: "local", partner: "partner"), now: now)
        XCTAssertEqual(hint.state, .ownHand)
        XCTAssertFalse(hint.canTake(at: now)); XCTAssertFalse(hint.canOpen(at: now))
    }
    func testRevokedOrUnauthorizedPairDeniesAllActions() {
        var revoked = pair(); revoked.revoked = true
        var unauthorized = partnership; unauthorized.isAuthorized = false
        for (p, record) in [(partnership, revoked), (unauthorized, pair())] {
            XCTAssertEqual(ReachHomeAvailability.resolve(partnership: p, pair: record, room: room(), now: now), .unavailable)
        }
    }
    func testMissingExpiredInactiveOrForeignRoomNeverLooksAvailable() {
        let rooms: [RoomRecord?] = [nil, room(active: false), room(expiry: 0), room(code: "OTHER"), room(partner: "outsider"), room(host: "outsider")]
        for candidate in rooms {
            XCTAssertEqual(ReachHomeAvailability.resolve(partnership: partnership, pair: pair(), room: candidate, now: now), .unavailable)
        }
    }
    func testIncompletePointerAndOutsiderMembershipFailClosed() {
        var outsider = pair(); outsider.hostUid = "outsider"
        for record in [pair(room: nil), pair(opener: nil), pair(opener: "outsider"), outsider] {
            XCTAssertEqual(ReachHomeAvailability.resolve(partnership: partnership, pair: record, room: room(), now: now), .unavailable)
        }
    }
    func testRoomExpiryImmediatelyDisablesTakeWithoutWaitingForRefresh() {
        let hint = ReachHomeAvailability.resolve(partnership: partnership, pair: pair(), room: room(expiry: 2), now: now)
        XCTAssertTrue(hint.canTake(at: now.addingTimeInterval(1)))
        XCTAssertFalse(hint.canTake(at: now.addingTimeInterval(2)))
    }
    func testAnsweredRoomCannotLookLikeANewInvitation() {
        var answered = room(); answered.answer = SessionDescriptionRecord(type: "answer", sdp: "existing")
        XCTAssertEqual(ReachHomeAvailability.resolve(partnership: partnership, pair: pair(), room: answered, now: now), .unavailable)
    }
}
