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

#if canImport(FirebaseFirestore)
    func testRoomAuthorizationErrorsAreDistinctAndDoNotExposeIdentifiers() {
        let membership = ReachErrorPresentation.message(FirestoreRoomStoreError.unauthorized)
        let session = ReachErrorPresentation.message(FirestoreRoomStoreError.authSessionChanged)
        let preflight = ReachErrorPresentation.message(StagingCallPreflightError.notAuthorized)
        XCTAssertNotEqual(membership, session)
        XCTAssertNotEqual(membership, preflight)
        XCTAssertNotEqual(session, preflight)
        XCTAssertNotEqual(ReachErrorPresentation.message(ReachRoomCoordinatorError.unauthorized), membership)
        XCTAssertNotEqual(ReachErrorPresentation.message(ReachRoomCoordinatorError.partnerChanged), membership)
        XCTAssertNotEqual(ReachErrorPresentation.message(ReachRoomCoordinatorError.pairNoLongerUsable), membership)
        XCTAssertTrue(membership.contains("Room creation"))
        XCTAssertTrue(session.contains("sign-in changed"))
        for message in [membership, session, preflight] {
            XCTAssertFalse(message.contains("hostUid"))
            XCTAssertFalse(message.contains("partnerUid"))
            XCTAssertFalse(message.contains("pairCode"))
        }
    }
#endif

    func testCallDocumentEvidenceRejectsCachedAndPendingSnapshots() {
        XCTAssertFalse(ReachCallDocumentPolicy.isAuthoritative(isFromCache: true, hasPendingWrites: false))
        XCTAssertFalse(ReachCallDocumentPolicy.isAuthoritative(isFromCache: false, hasPendingWrites: true))
        XCTAssertTrue(ReachCallDocumentPolicy.isAuthoritative(isFromCache: false, hasPendingWrites: false))
    }

    func testRoomExpiryAllowsAnOpenerClockAheadOfTheServer() {
        let serverNow = Date(timeIntervalSince1970: 1_700_000_000)
        let clientNow = serverNow.addingTimeInterval(30)
        let serverMilliseconds = Int64(serverNow.timeIntervalSince1970 * 1000)
        let maxExpiry = serverMilliseconds + 28_800_000
        XCTAssertGreaterThan(Int64(clientNow.addingTimeInterval(8 * 60 * 60).timeIntervalSince1970 * 1000), maxExpiry)
        let requestedExpiry = ReachRoomExpiry.epochMilliseconds(from: clientNow)
        XCTAssertEqual(requestedExpiry, maxExpiry - 30_000)
        XCTAssertGreaterThan(requestedExpiry, serverMilliseconds)
    }

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
