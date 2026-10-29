import Foundation

enum ReachSessionFreshness: Equatable {
    case current
    case expired
    case invalid
}

enum ReachSessionFreshnessPolicy {
    static let defaultMaximumAge: TimeInterval = 12 * 60 * 60

    static func evaluate(
        openedAt: Date,
        now: Date = Date(),
        maximumAge: TimeInterval = defaultMaximumAge
    ) -> ReachSessionFreshness {
        guard maximumAge > 0, openedAt <= now else { return .invalid }
        return now.timeIntervalSince(openedAt) <= maximumAge ? .current : .expired
    }
}
