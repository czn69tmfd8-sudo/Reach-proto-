import Foundation

enum IdentityMigrationDecision: Equatable {
    case freshNativeIdentity
    case continueAuthorized(pairCode: String)
    case migrationRequired(existingPairCode: String?)
    case identityChanged(previousUID: String, currentUID: String)
}

/// Prevents a native Firebase anonymous UID from silently being treated as the
/// already-authorized Safari identity. Production pairing remains locked until
/// identity continuity is explicitly proven or migrated.
enum IdentityMigrationPolicy {
    static func decide(
        stored: NativeDeviceIdentity?,
        currentFirebaseUID: String,
        knownWebPairCode: String? = nil
    ) -> IdentityMigrationDecision {
        guard let stored else {
            if knownWebPairCode != nil {
                return .migrationRequired(existingPairCode: knownWebPairCode)
            }
            return .freshNativeIdentity
        }

        if let previousUID = stored.firebaseUID, previousUID != currentFirebaseUID {
            return .identityChanged(previousUID: previousUID, currentUID: currentFirebaseUID)
        }

        if let pairCode = stored.authorizedPairCode {
            guard stored.firebaseUID == currentFirebaseUID else {
                return .migrationRequired(existingPairCode: pairCode)
            }
            return .continueAuthorized(pairCode: pairCode)
        }

        if knownWebPairCode != nil {
            return .migrationRequired(existingPairCode: knownWebPairCode)
        }

        return .freshNativeIdentity
    }
}
