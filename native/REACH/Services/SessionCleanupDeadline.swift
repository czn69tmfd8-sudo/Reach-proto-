import Foundation

/// Bound only the caller's wait. Firestore may finish its transaction later;
/// the operation must remain scoped to its original room and pair identity.
enum SessionCleanupDeadline {
    static func run(seconds: TimeInterval = 15, operation: @escaping @Sendable () async throws -> Void) async throws {
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let deadline = CallbackDeadline(continuation, operation: "session cleanup", seconds: seconds)
                // Ending media can cancel the task which detected failure. Cleanup
                // gets its own lifetime and does not inherit that cancellation.
                Task {
                    do { try await operation(); deadline.resolve(.success(())) }
                    catch { deadline.resolve(.failure(error)) }
                }
            }
        } catch let error as CallbackDeadlineError where error.operation == "session cleanup" {
            throw SessionCleanupTimeout()
        }
    }
}

struct SessionCleanupTimeout: LocalizedError, Equatable {
    var errorDescription: String? {
        "The server has not confirmed session cleanup. Reconnect and refresh pairing status before opening a fresh hand."
    }
}
