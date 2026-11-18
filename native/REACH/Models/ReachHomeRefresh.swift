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

    func allowsOpenPreflight(knownPair: Bool, pairRead: ReachHomeReadOutcome?,
                             roomRead: ReachHomeReadOutcome?, now: Date) -> Bool {
        guard knownPair, pairRead != .authorizationDenied else { return false }
        if state == .ready { return !canOpen(at: now) }
        let retrying = pairRead == .checking || pairRead?.isTransient == true ||
            roomRead == .checking || roomRead?.isTransient == true
        switch state {
        case .checking: return retrying
        case .ownHand, .partnerHand: return retrying && !paired(at: now)
        default: return false
        }
    }

    static func afterRoomReadFailure(_ outcome: ReachHomeReadOutcome) -> Self {
        outcome.isTransient ? .checking : .unavailable
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

/// Redacted results of read-only preflight. A local deadline says nothing about
/// what Firestore would have returned after the UI stopped waiting.
enum ReachHomeReadOutcome: String {
    case checking = "Checking"
    case verified = "Verified"
    case unavailable = "No eligible record"
    case localDeadline = "Local check timed out"
    case serviceUnavailable = "Network or service unavailable"
    case authorizationDenied = "Firestore authorization denied"
    case failed = "Read failed"

    init(error: Error) {
        let failure = error as NSError
        switch (failure.domain, failure.code) {
        case _ where error is CallbackDeadlineError:
            self = .localDeadline
        case ("FIRFirestoreErrorDomain", 7), ("FIRFirestoreErrorDomain", 16):
            self = .authorizationDenied
        case ("FIRFirestoreErrorDomain", 4), ("FIRFirestoreErrorDomain", 14),
             (NSURLErrorDomain, URLError.timedOut.rawValue),
             (NSURLErrorDomain, URLError.networkConnectionLost.rawValue),
             (NSURLErrorDomain, URLError.notConnectedToInternet.rawValue):
            self = .serviceUnavailable
        default:
            self = .failed
        }
    }

    var isTransient: Bool { self == .localDeadline || self == .serviceUnavailable }
}

struct ReachHomeReadSample {
    let outcome: ReachHomeReadOutcome
    let date = Date()
}

struct ReachHomeTransition {
    let previous: String
    let current: String
    let date = Date()
}

struct ReachCallPairScope: Sendable {
    let uid: String
    let code: String

    func matches(_ lock: MemberLockRecord) -> Bool {
        lock.pairCode == code
    }
}
