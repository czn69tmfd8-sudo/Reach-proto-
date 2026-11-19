import Foundation

struct ReachProfilePhotoScope: Equatable, Sendable {
    let code: String
    let own: String
    let partner: String
}

/// In-memory decoded portraits, bound to the exact server-authorized pair.
private enum ReachHomePortraitLease {
    // Each lease starts only after an authorized read of that specific photo.
    // Retaining an image or rechecking a call never renews its lease.
    static let own: Duration = .seconds(120)
    static let partner: Duration = .seconds(60)
}
struct ReachProfilePhotoCache<Portrait> {
    enum Result {
        case updated(Portrait?)
        case transientFailure
        case failed
        case denied
    }

    private(set) var scope: ReachProfilePhotoScope?
    private(set) var own: Portrait?
    private(set) var partner: Portrait?
    private(set) var authorizationGeneration = UUID()
    private var ownVerifiedAt: ContinuousClock.Instant?
    private var partnerVerifiedAt: ContinuousClock.Instant?

    mutating func setScope(_ scope: ReachProfilePhotoScope?) {
        guard self.scope != scope else { return }
        own = nil
        partner = nil
        ownVerifiedAt = nil
        partnerVerifiedAt = nil
        authorizationGeneration = UUID()
        self.scope = scope
    }

    func visible(expectedScope: ReachProfilePhotoScope?, authorized: Bool) -> (Portrait?, Portrait?) {
        guard authorized, let scope, scope == expectedScope else { return (nil, nil) }
        return (own, partner)
    }

    func visibleOnHome(expectedScope: ReachProfilePhotoScope?, accountID: String?,
                       active: Bool, now: ContinuousClock.Instant) -> (Portrait?, Portrait?) {
        guard active, let scope, scope == expectedScope, scope.own == accountID else { return (nil, nil) }
        let ownAge = ownVerifiedAt?.duration(to: now)
        let partnerAge = partnerVerifiedAt?.duration(to: now)
        let ownVisible = ownAge.map { $0 >= .zero && $0 < ReachHomePortraitLease.own } ?? false
        let partnerVisible = partnerAge.map { $0 >= .zero && $0 < ReachHomePortraitLease.partner } ?? false
        return (ownVisible ? own : nil, partnerVisible ? partner : nil)
    }

    mutating func apply(_ result: Result, ownPhoto: Bool, for scope: ReachProfilePhotoScope,
                        generation: UUID? = nil, now: ContinuousClock.Instant = ContinuousClock().now) {
        guard self.scope == scope, generation == nil || generation == authorizationGeneration else { return }
        let portrait: Portrait?
        switch result {
        case .denied:
            setScope(nil)
            return
        case .transientFailure: return
        case .failed: portrait = nil
        case .updated(let value): portrait = value
        }
        if ownPhoto {
            own = portrait
            ownVerifiedAt = portrait == nil ? nil : now
        } else {
            partner = portrait
            partnerVerifiedAt = portrait == nil ? nil : now
        }
    }
}
