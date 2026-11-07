import FirebaseAuth
import Foundation

// Immutable SDK handle; Firebase synchronizes its own operations and callbacks.
final class FirebaseAuthProvider: @unchecked Sendable, ReachAuthenticationProvider {
    func currentUID() async -> String? {
        Auth.auth().currentUser?.uid
    }

    func signInAnonymously() async throws -> String {
        let result = try await Auth.auth().signInAnonymously()
        return result.user.uid
    }
}
