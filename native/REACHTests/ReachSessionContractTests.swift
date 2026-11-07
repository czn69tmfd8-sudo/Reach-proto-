import XCTest
@testable import REACH

final class ReachSessionContractTests: XCTestCase {
    func testNativeSessionLifetimeMatchesEightHourWebContract() {
        XCTAssertEqual(ReachSessionContract.maximumAge, 8 * 60 * 60)
        XCTAssertEqual(FirestoreRoomStore.sessionLifetime, ReachSessionContract.maximumAge)
    }

    func testRoomIsCurrentOnlyWhileActiveAndBeforeExpiry() {
        let now = Date(timeIntervalSince1970: 1_000)
        let current = RoomRecord(
            hostUid: "byron",
            partnerUid: "aaron",
            pairCode: "PAIR01",
            createdAt: now.addingTimeInterval(-60),
            expiresAt: now.addingTimeInterval(60),
            active: true,
            offer: nil,
            answer: nil
        )
        XCTAssertTrue(current.isCurrent(at: now))

        var ended = current
        ended.active = false
        XCTAssertFalse(ended.isCurrent(at: now))

        var expired = current
        expired.expiresAt = now.addingTimeInterval(-1)
        XCTAssertFalse(expired.isCurrent(at: now))
    }
}
