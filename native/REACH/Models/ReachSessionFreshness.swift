import Foundation

enum ReachSessionFreshness: Equatable {
    case current
    case expired
    case invalid
}

enum ReachSessionContract {
    /// Must match the proven web SESSION_LENGTH_MS.
    static let maximumAge: TimeInterval = 8 * 60 * 60
}

enum ReachSessionFreshnessPolicy {
    static let defaultMaximumAge: TimeInterval = ReachSessionContract.maximumAge

    static func evaluate(
        openedAt: Date,
        now: Date = Date(),
        maximumAge: TimeInterval = defaultMaximumAge
    ) -> ReachSessionFreshness {
        guard maximumAge > 0, openedAt <= now else { return .invalid }
        return now.timeIntervalSince(openedAt) <= maximumAge ? .current : .expired
    }
}
