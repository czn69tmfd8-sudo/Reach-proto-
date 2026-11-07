import XCTest
@testable import REACH

final class ReachSignalingValidationTests: XCTestCase {
    func testValidOfferAndCandidate() throws {
        try ReachSignalingValidation.validate(
            ReachSessionDescription(kind: .offer, sdp: "v=0\r\n")
        )
        try ReachSignalingValidation.validate(
            ReachIceCandidate(sdp: "candidate:1 1 udp 1 127.0.0.1 5000 typ host", sdpMid: "0", sdpMLineIndex: 0)
        )
    }

    func testBlankDescriptionRejected() {
        XCTAssertThrowsError(
            try ReachSignalingValidation.validate(
                ReachSessionDescription(kind: .answer, sdp: "  ")
            )
        )
    }

    func testOversizedDescriptionRejected() {
        XCTAssertThrowsError(
            try ReachSignalingValidation.validate(
                ReachSessionDescription(
                    kind: .offer,
                    sdp: String(repeating: "x", count: ReachSignalingValidation.maximumSDPBytes + 1)
                )
            )
        )
    }

    func testNegativeCandidateIndexRejected() {
        XCTAssertThrowsError(
            try ReachSignalingValidation.validate(
                ReachIceCandidate(sdp: "candidate:1", sdpMid: "0", sdpMLineIndex: -1)
            )
        )
    }

    func testOversizedCandidateRejected() {
        XCTAssertThrowsError(
            try ReachSignalingValidation.validate(
                ReachIceCandidate(
                    sdp: String(repeating: "x", count: ReachSignalingValidation.maximumCandidateBytes + 1),
                    sdpMid: "0",
                    sdpMLineIndex: 0
                )
            )
        )
    }
}
