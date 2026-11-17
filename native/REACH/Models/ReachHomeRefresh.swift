import Foundation

extension ReachHomeAvailability {
    static func pairingIsFresh(checkedAt: Date, now: Date) -> Bool {
        checkedAt.addingTimeInterval(15) > now
    }

    static func retainsPairingAfterRefreshFailure(transient: Bool, checkedAt: Date, now: Date) -> Bool {
        transient && Self.pairingIsFresh(checkedAt: checkedAt, now: now)
    }

    /// Firebase's callback can outlive a cancelled Swift task. Bound the UI's
    /// wait and discard any result delivered after the deadline.
    static func boundedRefresh<Value: Sendable>(
        seconds: TimeInterval = 8, operation: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        let request = Task { try await operation() }
        defer { request.cancel() }
        return try await withCheckedThrowingContinuation { continuation in
            let deadline = CallbackDeadline(continuation, operation: "Home availability refresh", seconds: seconds)
            Task {
                do { deadline.resolve(.success(try await request.value)) }
                catch { deadline.resolve(.failure(error)) }
            }
        }
    }
}
