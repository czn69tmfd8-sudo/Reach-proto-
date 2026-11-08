import XCTest
@testable import REACH

final class ReachCallReviewTests: XCTestCase {
    func testDiagnosticsAreBoundedAndContainOnlyEventLabelsAndTimes() {
        var log = ReachPrivateDiagnostics()
        for second in 0..<30 { log.record(.preparing, at: Date(timeIntervalSince1970: Double(second))) }
        XCTAssertEqual(log.events.count, 20)
        XCTAssertEqual(log.events.first?.date, Date(timeIntervalSince1970: 10))
        log.record(.ended)
        XCTAssertEqual(log.events.last?.event, .ended)
    }
    func testBackendErrorsUseFixedCopyWithoutLeakingRemotePayloads() {
        XCTAssertTrue(ReachFailureCopy.backend(domain: "FIRFirestoreErrorDomain", code: 7).contains("authorization"))
        XCTAssertTrue(ReachFailureCopy.backend(domain: "FIRFirestoreErrorDomain", code: 14).contains("reached"))
        XCTAssertTrue(ReachFailureCopy.backend(domain: NSURLErrorDomain, code: -1009).contains("network"))
        XCTAssertFalse(ReachFailureCopy.backend(domain: "secret-uid", code: 42).contains("secret-uid"))
    }
#if canImport(FirebaseFirestore)
    func testCallPreflightFailureIsDistinguishableWithoutLeakingPairingDetails() {
        let message = ReachErrorPresentation.message(StagingCallPreflightError.notAuthorized)
        XCTAssertTrue(message.contains("before opening a room"))
        XCTAssertFalse(message.contains("hostUid"))
        XCTAssertFalse(message.contains("pairCode"))
        XCTAssertNotEqual(message, ReachErrorPresentation.message(ReachRoomCoordinatorError.unauthorized))
    }
#endif

    func testOnlyShortLivedValidRelayGrantsAreEligibleForFutureUse() {
        let now = Date()
        func grant(_ urls: [String], seconds: Double = 300, username: String = "ephemeral") -> ReachRelayGrant {
            ReachRelayGrant(urls: urls, username: username, credential: "short-lived", expiresAt: now.addingTimeInterval(seconds))
        }
        XCTAssertTrue(grant(["turns:relay.example.com:443?transport=tcp"]).isUsable(at: now))
        XCTAssertTrue(grant(["turn:relay.example.com:3478?transport=udp"]).isUsable(at: now))
        for url in ["https://relay.example.com", "turn:relay.example.com:99999?transport=udp", "turn:user@relay.example.com:3478?transport=udp", "turn:relay.example.com:3478"] {
            XCTAssertFalse(grant([url]).isUsable(at: now))
        }
        XCTAssertFalse(grant([], seconds: 300).isUsable(at: now))
        XCTAssertFalse(grant(["turns:relay.example.com:443?transport=tcp"], seconds: -1).isUsable(at: now))
        XCTAssertFalse(grant(["turns:relay.example.com:443?transport=tcp"], seconds: 601).isUsable(at: now))
        XCTAssertFalse(grant(["turns:relay.example.com:443?transport=tcp"], username: "").isUsable(at: now))
    }
}
