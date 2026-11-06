import XCTest
@testable import REACH

final class SignalingInboxTests: XCTestCase {
    private let offer = ReachSessionDescription(kind: .offer, sdp: "v=0\r\no=offer")
    private func candidate(_ id: Int) -> ReachIceCandidate {
        ReachIceCandidate(sdp: "candidate:\(id)", sdpMid: "0", sdpMLineIndex: 0)
    }
    private func readyInbox() throws -> SignalingInbox {
        var inbox = SignalingInbox()
        _ = try inbox.accept(offer); try inbox.remoteDescriptionApplied()
        return inbox
    }
    func testCandidatesWaitForAppliedRemoteDescriptionAndDrainOnce() throws {
        var inbox = SignalingInbox(); try inbox.accept(candidate(1))
        XCTAssertNil(inbox.beginDrain()); XCTAssertTrue(try inbox.accept(offer))
        XCTAssertNil(inbox.beginDrain()); try inbox.remoteDescriptionApplied()
        let owner = try XCTUnwrap(inbox.beginDrain())
        XCTAssertEqual(inbox.nextCandidate(owner: owner), candidate(1))
        XCTAssertNil(inbox.nextCandidate(owner: owner)); inbox.finishDrain(owner: owner)
        XCTAssertNil(inbox.beginDrain())
    }
    func testDuplicateSnapshotsAreIgnored() throws {
        var inbox = try readyInbox()
        XCTAssertFalse(try inbox.accept(offer)); try inbox.accept(candidate(1))
        let owner = try XCTUnwrap(inbox.beginDrain())
        XCTAssertEqual(inbox.nextCandidate(owner: owner), candidate(1))
        try inbox.accept(candidate(1)); XCTAssertNil(inbox.nextCandidate(owner: owner))
    }
    func testChangedDescriptionCannotRenegotiateOneShotRoom() throws {
        var inbox = try readyInbox()
        XCTAssertThrowsError(try inbox.accept(ReachSessionDescription(kind: .offer, sdp: "changed")))
    }
    func testCandidateQueueHasBoundAndResetDoesNotLeakSessionState() throws {
        var inbox = try readyInbox()
        for id in 0..<512 { try inbox.accept(candidate(id)) }
        XCTAssertThrowsError(try inbox.accept(candidate(512)))
        inbox = SignalingInbox(); XCTAssertNil(inbox.description); XCTAssertFalse(inbox.ready)
        XCTAssertNil(inbox.beginDrain())
    }
    func testConcurrentListenerCannotClaimSecondDrain() throws {
        var inbox = try readyInbox(); try inbox.accept(candidate(1))
        let owner = try XCTUnwrap(inbox.beginDrain())
        XCTAssertNil(inbox.beginDrain())
        XCTAssertNil(inbox.nextCandidate(owner: UUID()))
        inbox.finishDrain(owner: UUID()); XCTAssertNil(inbox.beginDrain())
        XCTAssertEqual(inbox.nextCandidate(owner: owner), candidate(1))
    }
    func testCandidateArrivingDuringAwaitStaysBehindPendingCandidates() throws {
        var inbox = try readyInbox(); try inbox.accept(candidate(1)); try inbox.accept(candidate(2))
        let owner = try XCTUnwrap(inbox.beginDrain())
        XCTAssertEqual(inbox.nextCandidate(owner: owner), candidate(1))
        // While the first SDK add callback is pending, another listener adds ICE.
        try inbox.accept(candidate(3)); XCTAssertNil(inbox.beginDrain())
        XCTAssertEqual(inbox.nextCandidate(owner: owner), candidate(2))
        XCTAssertEqual(inbox.nextCandidate(owner: owner), candidate(3))
        inbox.finishDrain(owner: owner)
        try inbox.accept(candidate(4)); XCTAssertNotNil(inbox.beginDrain())
    }
    func testOldDrainOwnerCannotConsumeOrUnlockFreshRoom() throws {
        var inbox = try readyInbox(); try inbox.accept(candidate(1))
        let old = try XCTUnwrap(inbox.beginDrain())
        inbox = try readyInbox(); try inbox.accept(candidate(2))
        let current = try XCTUnwrap(inbox.beginDrain())
        XCTAssertNil(inbox.nextCandidate(owner: old)); inbox.finishDrain(owner: old)
        XCTAssertNil(inbox.beginDrain())
        XCTAssertEqual(inbox.nextCandidate(owner: current), candidate(2))
    }
    func testDescriptionCannotBeMarkedAppliedBeforeItIsReceived() {
        var inbox = SignalingInbox()
        XCTAssertThrowsError(try inbox.remoteDescriptionApplied())
        XCTAssertFalse(inbox.ready)
    }
}
