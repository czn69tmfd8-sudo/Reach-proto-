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

    private func homeCache(at now: ContinuousClock.Instant) -> ReachProfilePhotoCache<Int> {
        var cache = ReachProfilePhotoCache<Int>()
        cache.setScope(scope)
        cache.apply(.updated(1), ownPhoto: true, for: scope, now: now)
        cache.apply(.updated(2), ownPhoto: false, for: scope, now: now)
        return cache
    }

    func testHomePortraitsOutlivePairingFreshnessWithIndependentBounds() {
        let now = ContinuousClock().now
        var relationship = ReachHomeRelationship()
        relationship.verify(scope, now: now)
        let cache = homeCache(at: now)
        let gap = now.advanced(by: .seconds(31))
        XCTAssertFalse(relationship.permitsPortraits(uid: scope.own, active: true, now: gap))
        let both = cache.visibleOnHome(expectedScope: relationship.scope, accountID: scope.own, active: true, now: gap)
        XCTAssertEqual(both.0, 1)
        XCTAssertEqual(both.1, 2)

        let partnerExpired = cache.visibleOnHome(expectedScope: scope, accountID: scope.own, active: true,
                                                 now: now.advanced(by: .seconds(60)))
        XCTAssertEqual(partnerExpired.0, 1)
        XCTAssertNil(partnerExpired.1)
        let ownerExpired = cache.visibleOnHome(expectedScope: scope, accountID: scope.own, active: true,
                                               now: now.advanced(by: .seconds(120)))
        XCTAssertNil(ownerExpired.0)
        XCTAssertNil(ownerExpired.1)
    }

    func testHomeProjectionSurvivesTabAndCallTransitionsForSameScope() {
        let now = ContinuousClock().now
        let cache = homeCache(at: now)
        var room = ReachHomeRoomGeneration()
        let portraitGeneration = cache.authorizationGeneration
        // Re-render before leaving Home, on return, and after room setup/teardown resets.
        for seconds in [0, 5, 10, 20] {
            room.reset()
            let portraits = cache.visibleOnHome(expectedScope: scope, accountID: scope.own, active: true,
                                                 now: now.advanced(by: .seconds(seconds)))
            XCTAssertEqual(portraits.0, 1)
            XCTAssertEqual(portraits.1, 2)
            XCTAssertEqual(cache.authorizationGeneration, portraitGeneration)
        }
        let inactive = cache.visibleOnHome(expectedScope: scope, accountID: scope.own, active: false, now: now)
        XCTAssertNil(inactive.0)
        XCTAssertNil(inactive.1)
    }

    func testTemporaryFailureDoesNotRenewEitherPhotoAndSuccessRenewsOnlyItsSlot() {
        let now = ContinuousClock().now
        var cache = homeCache(at: now)
        let retry = now.advanced(by: .seconds(45))
        cache.apply(.transientFailure, ownPhoto: false, for: scope, now: retry)
        cache.apply(.updated(3), ownPhoto: true, for: scope, now: retry)
        let retained = cache.visibleOnHome(expectedScope: scope, accountID: scope.own, active: true, now: retry)
        XCTAssertEqual(retained.0, 3)
        XCTAssertEqual(retained.1, 2)
        let expired = cache.visibleOnHome(expectedScope: scope, accountID: scope.own, active: true,
                                         now: now.advanced(by: .seconds(120)))
        XCTAssertEqual(expired.0, 3)
        XCTAssertNil(expired.1)
    }

    func testIndependentHardFailureAndConfirmedRemovalDoNotClearOtherSlot() {
        let now = ContinuousClock().now
        var cache = homeCache(at: now)
        cache.apply(.failed, ownPhoto: false, for: scope)
        let partnerFailed = cache.visibleOnHome(expectedScope: scope, accountID: scope.own, active: true, now: now)
        XCTAssertEqual(partnerFailed.0, 1)
        XCTAssertNil(partnerFailed.1)
        cache.apply(.updated(2), ownPhoto: false, for: scope, now: now)
        cache.apply(.updated(nil), ownPhoto: true, for: scope)
        let ownerRemoved = cache.visibleOnHome(expectedScope: scope, accountID: scope.own, active: true, now: now)
        XCTAssertNil(ownerRemoved.0)
        XCTAssertEqual(ownerRemoved.1, 2)
    }

    func testRevocationSignOutAndPartnerReplacementImmediatelyHideProtectedPhotos() {
        let now = ContinuousClock().now
        var cache = homeCache(at: now)
        let replaced = ReachProfilePhotoScope(code: scope.code, own: scope.own, partner: "replacement")
        for (pair, account) in [(scope, nil as String?), (scope, "different account"), (replaced, scope.own)] {
            let hidden = cache.visibleOnHome(expectedScope: pair, accountID: account, active: true, now: now)
            XCTAssertNil(hidden.0)
            XCTAssertNil(hidden.1)
        }
        cache.setScope(nil)
        cache.setScope(replaced)
        XCTAssertNil(cache.own)
        XCTAssertNil(cache.partner)
    }

    func testLateCallbacksAfterDenialAreRejectedEvenAfterSameScopeIsReacquired() {
        let now = ContinuousClock().now
        var cache = homeCache(at: now)
        let oldGeneration = cache.authorizationGeneration
        cache.apply(.denied, ownPhoto: false, for: scope, generation: oldGeneration)
        XCTAssertNil(cache.own)
        XCTAssertNil(cache.partner)

        cache.setScope(scope)
        let freshGeneration = cache.authorizationGeneration
        cache.apply(.updated(4), ownPhoto: true, for: scope, generation: freshGeneration, now: now)
        cache.apply(.updated(5), ownPhoto: false, for: scope, generation: oldGeneration, now: now)
        cache.apply(.denied, ownPhoto: false, for: scope, generation: oldGeneration)
        XCTAssertEqual(cache.own, 4)
        XCTAssertNil(cache.partner)
    }
}
