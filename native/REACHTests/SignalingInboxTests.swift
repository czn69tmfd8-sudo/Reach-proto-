import XCTest
@testable import REACH

final class SignalingInboxTests: XCTestCase {
    private let offer = ReachSessionDescription(kind: .offer, sdp: "v=0\r\no=offer")
    private let candidate = ReachIceCandidate(sdp: "candidate:1", sdpMid: "0", sdpMLineIndex: 0)

    func testCandidatesWaitForAppliedRemoteDescriptionAndDrainOnce() throws {
        var inbox = SignalingInbox()
        XCTAssertTrue(try inbox.accept(candidate).isEmpty)
        XCTAssertTrue(try inbox.accept(offer))
        XCTAssertFalse(inbox.ready)
        XCTAssertEqual(inbox.remoteDescriptionApplied(), [candidate])
        XCTAssertTrue(inbox.remoteDescriptionApplied().isEmpty)
    }

    func testDuplicateSnapshotsAreIgnored() throws {
        var inbox = SignalingInbox()
        XCTAssertTrue(try inbox.accept(offer))
        XCTAssertFalse(try inbox.accept(offer))
        _ = inbox.remoteDescriptionApplied()
        XCTAssertEqual(try inbox.accept(candidate), [candidate])
        XCTAssertTrue(try inbox.accept(candidate).isEmpty)
    }

    func testChangedDescriptionCannotRenegotiateOneShotRoom() throws {
        var inbox = SignalingInbox()
        _ = try inbox.accept(offer)
        XCTAssertThrowsError(try inbox.accept(ReachSessionDescription(kind: .offer, sdp: "changed")))
    }

    func testCandidateQueueHasBoundAndResetDoesNotLeakSessionState() throws {
        var inbox = SignalingInbox()
        for index in 0..<512 {
            _ = try inbox.accept(ReachIceCandidate(sdp: "candidate:\(index)", sdpMid: "0", sdpMLineIndex: 0))
        }
        XCTAssertThrowsError(try inbox.accept(ReachIceCandidate(sdp: "overflow", sdpMid: nil, sdpMLineIndex: 0)))
        inbox = SignalingInbox()
        XCTAssertNil(inbox.description)
        XCTAssertFalse(inbox.ready)
        XCTAssertTrue(inbox.remoteDescriptionApplied().isEmpty)
    }
}
