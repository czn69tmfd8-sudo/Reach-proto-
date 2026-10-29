import FirebaseAuth
import Foundation

final class FirebaseAuthProvider: ReachAuthenticationProvider {
    func currentUID() async -> String? {
        Auth.auth().currentUser?.uid
    }

    func signInAnonymously() async throws -> String {
        let result = try await Auth.auth().signInAnonymously()
        return result.user.uid
    }
}
