import XCTest
@testable import REACH

final class LocalCandidateOutboxTests: XCTestCase {
    private func candidate(_ id: Int) -> ReachIceCandidate {
        ReachIceCandidate(sdp: "candidate:\(id)", sdpMid: "0", sdpMLineIndex: 0)
    }
    func testLocalCandidatesDrainInOrder() throws {
        var queue = LocalCandidateOutbox()
        try queue.enqueue(candidate(1)); try queue.enqueue(candidate(2))
        XCTAssertEqual(queue.next(), candidate(1)); XCTAssertEqual(queue.next(), candidate(2))
        XCTAssertNil(queue.next())
    }
    func testDuplicatesRemainSuppressedAfterPublication() throws {
        var queue = LocalCandidateOutbox()
        try queue.enqueue(candidate(1)); try queue.enqueue(candidate(1))
        XCTAssertEqual(queue.next(), candidate(1))
        try queue.enqueue(candidate(1)); XCTAssertNil(queue.next())
    }
    func testLimitAppliesAcrossAlreadyPublishedCandidates() throws {
        var queue = LocalCandidateOutbox()
        for id in 0..<LocalCandidateOutbox.limit {
            try queue.enqueue(candidate(id)); XCTAssertEqual(queue.next(), candidate(id))
        }
        XCTAssertThrowsError(try queue.enqueue(candidate(512)))
        XCTAssertNoThrow(try queue.enqueue(candidate(0)))
        XCTAssertNil(queue.next())
    }
    func testMalformedCandidateDoesNotConsumeQueueCapacity() throws {
        var queue = LocalCandidateOutbox()
        XCTAssertThrowsError(try queue.enqueue(ReachIceCandidate(sdp: "", sdpMid: nil, sdpMLineIndex: -1)))
        try queue.enqueue(candidate(1)); XCTAssertEqual(queue.next(), candidate(1))
    }
    func testNewRoomDoesNotRetainPriorQueueOrDuplicateHistory() throws {
        var queue = LocalCandidateOutbox()
        try queue.enqueue(candidate(1)); queue = LocalCandidateOutbox()
        XCTAssertNil(queue.next())
        try queue.enqueue(candidate(1)); XCTAssertEqual(queue.next(), candidate(1))
    }
}
