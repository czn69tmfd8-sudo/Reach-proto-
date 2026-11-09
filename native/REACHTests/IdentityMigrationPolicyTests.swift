import XCTest
@testable import REACH

final class IdentityMigrationPolicyTests: XCTestCase {
    func testKnownWebPairOnFreshNativeInstallRequiresMigration() {
        XCTAssertEqual(
            IdentityMigrationPolicy.decide(
                stored: nil,
                currentFirebaseUID: "native-uid",
                knownWebPairCode: "ABC123"
            ),
            .migrationRequired(existingPairCode: "ABC123")
        )
    }

    func testSameAuthorizedNativeIdentityCanContinue() {
        let identity = NativeDeviceIdentity(
            installationID: UUID(),
            firebaseUID: "native-uid",
            authorizedPairCode: "ABC123",
            createdAt: Date()
        )
        XCTAssertEqual(
            IdentityMigrationPolicy.decide(
                stored: identity,
                currentFirebaseUID: "native-uid"
            ),
            .continueAuthorized(pairCode: "ABC123")
        )
    }

    func testChangedFirebaseUIDNeverInheritsAuthorization() {
        let identity = NativeDeviceIdentity(
            installationID: UUID(),
            firebaseUID: "old-uid",
            authorizedPairCode: "ABC123",
            createdAt: Date()
        )
        XCTAssertEqual(
            IdentityMigrationPolicy.decide(
                stored: identity,
                currentFirebaseUID: "new-uid"
            ),
            .identityChanged(previousUID: "old-uid", currentUID: "new-uid")
        )
    }

    func testRememberedPairWithoutMatchingUIDRequiresMigration() {
        let identity = NativeDeviceIdentity(
            installationID: UUID(),
            firebaseUID: nil,
            authorizedPairCode: "ABC123",
            createdAt: Date()
        )
        XCTAssertEqual(
            IdentityMigrationPolicy.decide(
                stored: identity,
                currentFirebaseUID: "native-uid"
            ),
            .migrationRequired(existingPairCode: "ABC123")
        )
    }
}
