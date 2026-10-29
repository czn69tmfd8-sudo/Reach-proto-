import XCTest
@testable import REACH

final class PairingAuthorizationTests: XCTestCase {
    func testAuthorizedMemberResolvesPartnership() {
        let result = PairingAuthorization.resolve(
            uid: "byron",
            memberLock: MemberLockRecord(pairCode: "ABC123"),
            pairCode: "ABC123",
            pair: PairRecord(
                hostUid: "byron",
                partnerUid: "aaron",
                revoked: false,
                activeRoom: nil,
                openedBy: nil
            )
        )

        XCTAssertEqual(
            result,
            .authorized(
                Partnership(
                    id: "ABC123",
                    localMemberID: "byron",
                    partnerMemberID: "aaron",
                    partnerDisplayName: "Partner",
                    isAuthorized: true
                )
            )
        )
    }

    func testRevokedPairIsRejected() {
        XCTAssertEqual(
            PairingAuthorization.resolve(
                uid: "byron",
                memberLock: MemberLockRecord(pairCode: "ABC123"),
                pairCode: "ABC123",
                pair: PairRecord(
                    hostUid: "byron",
                    partnerUid: "aaron",
                    revoked: true,
                    activeRoom: nil,
                    openedBy: nil
                )
            ),
            .pairRevoked
        )
    }

    func testDifferentUIDCannotUseRememberedPairCode() {
        XCTAssertEqual(
            PairingAuthorization.resolve(
                uid: "stranger",
                memberLock: MemberLockRecord(pairCode: "ABC123"),
                pairCode: "ABC123",
                pair: PairRecord(
                    hostUid: "byron",
                    partnerUid: "aaron",
                    revoked: false,
                    activeRoom: nil,
                    openedBy: nil
                )
            ),
            .memberMismatch
        )
    }
}
