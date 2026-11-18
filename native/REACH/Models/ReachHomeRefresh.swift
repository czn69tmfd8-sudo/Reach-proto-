import Foundation

extension ReachHomeAvailability {
    static func pairingIsFresh(checkedAt: Date, now: Date) -> Bool {
        checkedAt.addingTimeInterval(15) > now
    }

    /// A retryable read preserves the known relationship without renewing a hand hint.
    /// The caller clears identity on a definitive denial or an auth change.
    func afterRefreshFailure(transient: Bool, knownRelationship: Bool, now: Date) -> Self? {
        guard transient, knownRelationship else { return nil }
        return paired(at: now) ? self : .checking
    }

    static func afterRoomCheck(
        partnership: Partnership, pair: PairRecord, room: RoomRecord?,
        pairCheckedAt: Date, now: Date
    ) -> Self {
        var hint = ReachHandControls.verifiedAvailability(partnership: partnership, pair: pair, room: room, now: now)
        hint.verifiedUntil = min(hint.verifiedUntil, pairCheckedAt.addingTimeInterval(15))
        return hint
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
