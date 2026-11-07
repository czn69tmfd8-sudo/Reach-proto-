import FirebaseFirestore
import Foundation

enum FirebaseDependencyFactory {
    static func staging() throws -> FirebaseReachDependencies {
        try FirebaseBootstrap.configureStaging()

        let db = Firestore.firestore()

        return FirebaseReachDependencies(
            auth: FirebaseAuthProvider(),
            pairs: FirestorePairStore(db: db),
            rooms: FirestoreRoomStore(db: db)
        )
    }
}
