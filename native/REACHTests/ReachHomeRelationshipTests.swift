import XCTest
@testable import REACH

final class ReachHomeRelationshipTests: XCTestCase {
    private let scope = ReachProfilePhotoScope(code: "pair", own: "member", partner: "partner")
    private let start = ContinuousClock().now

    func testIdleRefreshGapOutlivesCallHintButPortraitLeaseRemainsBounded() {
        var identity = ReachHomeRelationship()
        identity.verify(scope, now: start)
        XCTAssertTrue(identity.permitsPortraits(uid: scope.own, active: true, now: start.advanced(by: .seconds(16))))
        XCTAssertFalse(identity.permitsPortraits(uid: scope.own, active: true, now: start.advanced(by: .seconds(30))))
        XCTAssertEqual(identity.scope, scope)
    }

    func testTabRoundTripKeepsScopeAndDecodedPortraitsThroughOneSidedFailure() {
        var identity = ReachHomeRelationship()
        identity.verify(scope, now: start)
        let generation = identity.generation
        var cache = ReachProfilePhotoCache<String>()
        cache.setScope(scope)
        cache.apply(.updated("own"), ownPhoto: true, for: scope)
        cache.apply(.updated("partner"), ownPhoto: false, for: scope)
        cache.apply(.transientFailure, ownPhoto: true, for: scope)
        identity.verify(scope, now: start.advanced(by: .seconds(5)))
        let both = cache.visible(expectedScope: identity.scope, authorized: true)
        XCTAssertEqual(both.0, "own")
        XCTAssertEqual(both.1, "partner")
        cache.apply(.failed, ownPhoto: true, for: scope)
        XCTAssertNil(cache.visible(expectedScope: identity.scope, authorized: true).0)
        XCTAssertEqual(cache.visible(expectedScope: identity.scope, authorized: true).1, "partner")
        XCTAssertEqual(identity.generation, generation)
    }

    func testForegroundReentryDuringTemporaryFailureAndAccountSwitch() {
        var identity = ReachHomeRelationship()
        identity.verify(scope, now: start)
        let returnTime = start.advanced(by: .seconds(20))
        XCTAssertFalse(identity.permitsPortraits(uid: scope.own, active: false, now: returnTime))
        XCTAssertTrue(identity.permitsPortraits(uid: scope.own, active: true, now: returnTime))
        XCTAssertFalse(identity.permitsPortraits(uid: "other", active: true, now: returnTime))
    }

    func testRevocationAndPartnerReplacementRotateScopeGeneration() {
        var identity = ReachHomeRelationship()
        identity.verify(scope, now: start)
        let original = identity.generation
        identity.verify(nil, now: start)
        let revoked = identity.generation
        XCTAssertNotEqual(original, revoked)
        XCTAssertFalse(identity.permitsPortraits(uid: scope.own, active: true, now: start))
        let replacement = ReachProfilePhotoScope(code: scope.code, own: scope.own, partner: "replacement")
        identity.verify(replacement, now: start)
        XCTAssertNotEqual(revoked, identity.generation)
        var cache = ReachProfilePhotoCache<String>()
        cache.setScope(scope)
        cache.apply(.updated("old"), ownPhoto: false, for: scope)
        XCTAssertNil(cache.visible(expectedScope: identity.scope, authorized: true).1)
    }

    func testRoomListenerSupersedesPendingPollAndTeardownInvalidatesOldObserver() {
        var room = ReachHomeRoomGeneration()
        let poll = room
        room.acceptEvent()
        XCTAssertEqual(room.id, poll.id)
        XCTAssertNotEqual(room, poll)
        let observer = room.id
        room.reset()
        XCTAssertNotEqual(room.id, observer)
    }

    func testReceiverTransitionsFromPublishedPointerToOfferAndRejectsExpiredReconnect() {
        let now = Date()
        let pair = PairRecord(hostUid: scope.partner, partnerUid: scope.own, revoked: false, activeRoom: "room", openedBy: scope.partner)
        let partnership = Partnership(id: scope.code, localMemberID: scope.own, partnerMemberID: scope.partner,
                                      partnerDisplayName: "Partner", isAuthorized: true)
        var room = RoomRecord(hostUid: scope.partner, partnerUid: scope.own, pairCode: scope.code,
                              createdAt: now, expiresAt: now.addingTimeInterval(3), active: true, offer: nil, answer: nil)
        XCTAssertFalse(ReachHandControls.verifiedAvailability(partnership: partnership, pair: pair, room: room, now: now).canTake(at: now))
        room.offer = SessionDescriptionRecord(type: "offer", sdp: "v=0")
        XCTAssertTrue(ReachHandControls.verifiedAvailability(partnership: partnership, pair: pair, room: room, now: now).canTake(at: now))
        let reconnect = now.addingTimeInterval(3)
        XCTAssertFalse(ReachHandControls.verifiedAvailability(partnership: partnership, pair: pair, room: room, now: reconnect).canTake(at: reconnect))
    }
}
