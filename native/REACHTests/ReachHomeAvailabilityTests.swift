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
        let outsider = PairRecord(hostUid: "outsider", partnerUid: "partner", revoked: false,
                                  activeRoom: "room", openedBy: "partner")
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

    func testHomeCardsRespectPairingBusyStateAndExpiry() {
        for hint in [ReachHomeAvailability.unpaired, .checking, .invitation, .unavailable] {
            let controls = ReachHandControls(availability: hint, now: now, phase: .idle, roomID: nil, busy: false)
            XCTAssertFalse(controls.canOpen)
            XCTAssertFalse(controls.canTake)
            XCTAssertFalse(controls.canWithdraw)
        }
        let ready = ReachHomeAvailability(state: .ready, verifiedUntil: now.addingTimeInterval(2))
        XCTAssertTrue(ReachHandControls(availability: ready, now: now, phase: .idle, roomID: nil, busy: false).canOpen)
        XCTAssertFalse(ReachHandControls(availability: ready, now: now, phase: .idle, roomID: nil, busy: false).canTake)
        XCTAssertFalse(ReachHandControls(availability: ready, now: now, phase: .idle, roomID: nil, busy: true).canOpen)
        XCTAssertFalse(ReachHandControls(availability: ready, now: now.addingTimeInterval(2), phase: .idle, roomID: nil, busy: false).canOpen)
    }

    func testTakeCardRequiresAnUnansweredValidOfferAndSpecificRoom() {
        var candidate = room(expiry: 2)
        func controls(at time: Date, roomID: String? = "room", phase: ReachCallPhase = .idle, busy: Bool = false) -> ReachHandControls {
            let hint = ReachHandControls.verifiedAvailability(partnership: partnership, pair: pair(), room: candidate, now: now)
            return ReachHandControls(availability: hint, now: time, phase: phase, roomID: roomID, busy: busy)
        }

        XCTAssertFalse(controls(at: now).canTake)
        candidate.offer = SessionDescriptionRecord(type: "offer", sdp: "   ")
        XCTAssertFalse(controls(at: now).canTake)
        candidate.offer = SessionDescriptionRecord(type: "answer", sdp: "v=0")
        XCTAssertFalse(controls(at: now).canTake)
        candidate.offer = SessionDescriptionRecord(type: "offer", sdp: "v=0")
        XCTAssertTrue(controls(at: now).canTake)
        XCTAssertFalse(controls(at: now).canOpen)
        XCTAssertFalse(controls(at: now, roomID: nil).canTake)
        XCTAssertFalse(controls(at: now, phase: .connecting).canTake)
        XCTAssertFalse(controls(at: now, busy: true).canTake)
        XCTAssertFalse(controls(at: now.addingTimeInterval(2)).canTake)
        candidate.answer = SessionDescriptionRecord(type: "answer", sdp: "v=0")
        XCTAssertFalse(controls(at: now).canTake)
    }

    func testWithdrawalTargetsOnlyTheVerifiedOwnedInvitation() {
        let ownPair = pair(opener: "local")
        let ownRoom = room(host: "local", partner: "partner")
        let hint = ReachHandControls.verifiedAvailability(partnership: partnership, pair: ownPair, room: ownRoom, now: now)
        let controls = ReachHandControls(availability: hint, now: now, phase: .idle, roomID: "room", busy: false)
        XCTAssertTrue(controls.showsOutgoing)
        XCTAssertTrue(controls.canWithdraw)
        XCTAssertFalse(controls.canOpen)
        XCTAssertFalse(controls.canTake)
        XCTAssertFalse(ReachHandControls(availability: hint, now: now.addingTimeInterval(15), phase: .idle, roomID: "room", busy: false).canWithdraw)
        XCTAssertTrue(ReachHandControls(availability: .checking, now: now, phase: .outgoing, roomID: nil, busy: true).canWithdraw)

        XCTAssertTrue(ReachHandControls.canWithdraw(roomID: "room", partnership: partnership, pair: ownPair))
        XCTAssertFalse(ReachHandControls.canWithdraw(roomID: "older-room", partnership: partnership, pair: ownPair))
        XCTAssertFalse(ReachHandControls.canWithdraw(roomID: "room", partnership: partnership, pair: pair()))
        var revoked = ownPair
        revoked.revoked = true
        XCTAssertFalse(ReachHandControls.canWithdraw(roomID: "room", partnership: partnership, pair: revoked))
    }

    func testOnlyTransportConnectionShowsConnectedAndDisconnectClearsIt() {
        XCTAssertNil(ReachCallPhase.idle.title)
        XCTAssertEqual(ReachCallPhase.preparing.receiving(.negotiationStarted), .connecting)
        XCTAssertEqual(ReachCallPhase.outgoing.receiving(.negotiationStarted), .connecting)
        let connected = ReachCallPhase.connecting.receiving(.connected)
        XCTAssertEqual(connected, .connected)
        XCTAssertEqual(connected.receiving(.negotiationStarted), .connected)
        let interrupted = connected.receiving(.disconnected)
        XCTAssertEqual(interrupted, .interrupted)
        XCTAssertNotEqual(interrupted.title, connected.title)
        XCTAssertEqual(interrupted.receiving(.connected), .connected)
        XCTAssertEqual(connected.receiving(.failed), .interrupted)
        XCTAssertEqual(connected.receiving(.closed), .interrupted)
        XCTAssertEqual(ReachCallPhase.ending.receiving(.connected), .ending)
        XCTAssertEqual(ReachCallPhase.idle.receiving(.connected), .idle)

        let ready = ReachHomeAvailability(state: .ready, verifiedUntil: now.addingTimeInterval(2))
        for phase in [ReachCallPhase.preparing, .connecting, connected, interrupted, .ending] {
            let controls = ReachHandControls(availability: ready, now: now, phase: phase, roomID: nil, busy: false)
            XCTAssertFalse(controls.canOpen)
            XCTAssertFalse(controls.canTake)
            XCTAssertFalse(controls.canWithdraw)
        }
    }
}
