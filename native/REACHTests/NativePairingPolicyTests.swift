import XCTest
@testable import REACH

final class NativePairingPolicyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 10_000)
    private let lock = MemberLockRecord(pairCode: "old-native-pair")

    func testFreshInstallationMayCreateNativePairWithoutImportingWebLocks() {
        XCTAssertTrue(NativePairingPolicy.canReplaceLock(uid: "a", lock: nil, previousPair: nil))
        XCTAssertEqual(ReachCollections.pairInvites, "nativeStaging/v1/pairInvites")
        XCTAssertEqual(ReachCollections.memberLocks, "nativeStaging/v1/memberLocks")
        XCTAssertEqual(ReachCollections.rooms, "nativeStaging/v1/rooms")
    }

    func testActivePairCannotBeReplaced() {
        XCTAssertFalse(NativePairingPolicy.canReplaceLock(uid: "a", lock: lock, previousPair: pair()))
    }

    func testRevocationAllowsEachOriginalMemberToPairAgainWithSameIdentity() {
        var previous = pair(); previous.revoked = true
        XCTAssertTrue(NativePairingPolicy.canReplaceLock(uid: "a", lock: lock, previousPair: previous))
        XCTAssertTrue(NativePairingPolicy.canReplaceLock(uid: "b", lock: lock, previousPair: previous))
        XCTAssertFalse(NativePairingPolicy.canReplaceLock(uid: "outsider", lock: lock, previousPair: previous))
    }

    func testMissingPriorPairDoesNotReleaseLock() {
        XCTAssertFalse(NativePairingPolicy.canReplaceLock(uid: "a", lock: lock, previousPair: nil))
    }

    func testOnlyUnclaimedUnrevokedUnexpiredInvitationCanBeAcceptedByDifferentUID() {
        var invitation = PairRecord(hostUid: "a", partnerUid: nil, revoked: false, activeRoom: nil, openedBy: nil, invitationExpiresAt: now.addingTimeInterval(10))
        XCTAssertTrue(NativePairingPolicy.canAccept(uid: "b", invitation: invitation, now: now))
        XCTAssertFalse(NativePairingPolicy.canAccept(uid: "a", invitation: invitation, now: now))
        invitation.revoked = true
        XCTAssertFalse(NativePairingPolicy.canAccept(uid: "b", invitation: invitation, now: now))
        invitation.revoked = false;invitation.invitationExpiresAt = now
        XCTAssertFalse(NativePairingPolicy.canAccept(uid: "b", invitation: invitation, now: now))
        invitation.invitationExpiresAt = nil
        XCTAssertFalse(NativePairingPolicy.canAccept(uid: "b", invitation: invitation, now: now))
        XCTAssertFalse(NativePairingPolicy.canAccept(uid: "c", invitation: pair(), now: now))
    }

    func testRevokedForeignPairDoesNotGrantRePairPresentation() {
        var foreign = pair();foreign.revoked = true
        XCTAssertEqual(PairingAuthorization.resolve(uid: "outsider", memberLock: lock, pairCode: lock.pairCode, pair: foreign), .memberMismatch)
    }

    func testAcceptedPartnershipDoesNotExpireWithInvitationWindow() {
        var accepted = pair();accepted.invitationExpiresAt = now.addingTimeInterval(-100)
        guard case .authorized = PairingAuthorization.resolve(uid: "a", memberLock: lock, pairCode: lock.pairCode, pair: accepted) else {
            return XCTFail("Invitation expiry must not silently revoke a consenting partnership")
        }
    }

    private func pair() -> PairRecord {
        PairRecord(hostUid: "a", partnerUid: "b", revoked: false, activeRoom: nil, openedBy: nil)
    }
}
