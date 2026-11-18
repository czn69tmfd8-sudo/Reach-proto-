import Foundation

/// Home identity and portrait display authorization have independent lifetimes.
struct ReachHomeRelationship {
    // The in-memory portrait lease is renewed only by a successful server
    // member-lock + pair check. Neither room events nor cache reads renew it.
    static let portraitLease: Duration = .seconds(30)

    private(set) var scope: ReachProfilePhotoScope?
    private(set) var generation = UUID()
    private var verifiedAt: ContinuousClock.Instant?

    mutating func verify(_ scope: ReachProfilePhotoScope?, now: ContinuousClock.Instant) {
        if scope != self.scope { generation = UUID() }
        self.scope = scope
        verifiedAt = scope == nil ? nil : now
    }

    func permitsPortraits(uid: String?, active: Bool, now: ContinuousClock.Instant) -> Bool {
        guard active, let scope, scope.own == uid, let verifiedAt else { return false }
        let age = verifiedAt.duration(to: now)
        return age >= .zero && age < Self.portraitLease
    }
}

/// Listener events supersede pending room reads. A new pointer, scene, or
/// relationship cannot inherit a previous observer's results.
struct ReachHomeRoomGeneration: Equatable {
    private(set) var id = UUID()
    private(set) var revision = 0

    mutating func reset() { self = Self() }
    mutating func acceptEvent() { revision += 1 }
}
