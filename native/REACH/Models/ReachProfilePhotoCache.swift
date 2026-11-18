struct ReachProfilePhotoScope: Equatable, Sendable {
    let code: String
    let own: String
    let partner: String
}

/// In-memory decoded portraits. Callers supply current display authorization
/// separately so retaining an image during refresh cannot extend access.
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

    mutating func setScope(_ scope: ReachProfilePhotoScope?) {
        guard self.scope != scope else { return }
        own = nil
        partner = nil
        self.scope = scope
    }

    func visible(expectedScope: ReachProfilePhotoScope?, authorized: Bool) -> (Portrait?, Portrait?) {
        guard authorized, let scope, scope == expectedScope else { return (nil, nil) }
        return (own, partner)
    }

    mutating func apply(_ result: Result, ownPhoto: Bool, for scope: ReachProfilePhotoScope) {
        guard self.scope == scope else { return }
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
        } else {
            partner = portrait
        }
    }
}
