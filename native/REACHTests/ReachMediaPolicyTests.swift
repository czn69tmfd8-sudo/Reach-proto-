import XCTest
@testable import REACH

final class ReachMediaPolicyTests: XCTestCase {
    func testOpenerPublishesOffer() {
        XCTAssertEqual(
            ReachMediaPolicy.initialActions(for: .opener),
            [.prepareLocalMedia, .publishOffer, .exchangeCandidates]
        )
    }

    func testJoinerWaitsForOfferThenAnswers() {
        XCTAssertEqual(
            ReachMediaPolicy.initialActions(for: .joiner),
            [.prepareLocalMedia, .awaitOffer, .publishAnswer, .exchangeCandidates]
        )
    }

    func testConnectedMediaIsHealthy() {
        XCTAssertEqual(
            ReachConnectionHealthPolicy.evaluate(
                signaling: .complete,
                media: .connected
            ),
            .healthy
        )
    }

    func testCompletedSignalingWithoutMediaIsDisconnected() {
        XCTAssertEqual(
            ReachConnectionHealthPolicy.evaluate(
                signaling: .complete,
                media: .idle
            ),
            .disconnected
        )
    }

    func testInterruptedMediaIsDegraded() {
        XCTAssertEqual(
            ReachConnectionHealthPolicy.evaluate(
                signaling: .complete,
                media: .interrupted
            ),
            .degraded
        )
    }
}
