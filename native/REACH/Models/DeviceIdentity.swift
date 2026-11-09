import Foundation

enum DeviceIdentityStatus: Equatable {
    case unconfigured
    case localIdentity(uid: String)
    case migrationRequired(existingPairCode: String?)
    case migrationPending
    case authorized(uid: String, pairCode: String)
    case failed(message: String)
}

struct NativeDeviceIdentity: Codable, Equatable {
    let installationID: UUID
    var firebaseUID: String?
    var authorizedPairCode: String?
    var createdAt: Date

    static func fresh() -> NativeDeviceIdentity {
        NativeDeviceIdentity(
            installationID: UUID(),
            firebaseUID: nil,
            authorizedPairCode: nil,
            createdAt: Date()
        )
    }
}
