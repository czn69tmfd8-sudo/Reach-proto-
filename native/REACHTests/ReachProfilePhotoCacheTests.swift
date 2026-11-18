import XCTest
@testable import REACH

final class ReachProfilePhotoCacheTests: XCTestCase {
    private let scope = ReachProfilePhotoScope(code: "pair", own: "owner", partner: "partner")

    private func seededCache() -> ReachProfilePhotoCache<Int> {
        var cache = ReachProfilePhotoCache<Int>()
        cache.setScope(scope)
        cache.apply(.updated(1), ownPhoto: true, for: scope)
        cache.apply(.updated(2), ownPhoto: false, for: scope)
        return cache
    }

    func testOnlyFreshAuthorizationRevealsMatchingRetainedPortraits() {
        var cache = seededCache()
        let hidden = cache.visible(expectedScope: scope, authorized: false)
        XCTAssertNil(hidden.0)
        XCTAssertNil(hidden.1)
        cache.setScope(scope)
        let fresh = cache.visible(expectedScope: scope, authorized: true)
        XCTAssertEqual(fresh.0, 1)
        XCTAssertEqual(fresh.1, 2)
    }

    func testOneSidedFailureOrRemovalDoesNotDiscardOtherPortrait() {
        var cache = seededCache()
        cache.apply(.transientFailure, ownPhoto: false, for: scope)
        cache.apply(.updated(3), ownPhoto: true, for: scope)
        XCTAssertEqual(cache.own, 3)
        XCTAssertEqual(cache.partner, 2)
        cache.apply(.updated(nil), ownPhoto: false, for: scope)
        XCTAssertNil(cache.partner)
        XCTAssertEqual(cache.own, 3)
        cache.apply(.updated(4), ownPhoto: false, for: scope)
        cache.apply(.failed, ownPhoto: true, for: scope)
        XCTAssertNil(cache.own)
        XCTAssertEqual(cache.partner, 4)
    }

    func testDenialClearsBothAndLateSiblingCannotRestoreAccess() {
        var cache = seededCache()
        cache.apply(.denied, ownPhoto: false, for: scope)
        cache.apply(.updated(3), ownPhoto: true, for: scope)
        XCTAssertNil(cache.scope)
        XCTAssertNil(cache.own)
        XCTAssertNil(cache.partner)
    }

    func testSignOutOrChangedPartnerCannotRevealPriorPortraits() {
        var cache = seededCache()
        let replacement = ReachProfilePhotoScope(code: scope.code, own: scope.own, partner: "new partner")
        XCTAssertNil(cache.visible(expectedScope: replacement, authorized: true).0)
        cache.setScope(replacement)
        cache.apply(.updated(3), ownPhoto: false, for: scope)
        XCTAssertNil(cache.partner)
        cache.apply(.updated(4), ownPhoto: true, for: replacement)
        cache.setScope(nil)
        XCTAssertNil(cache.visible(expectedScope: replacement, authorized: true).0)
    }
}
