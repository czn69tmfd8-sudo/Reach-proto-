import XCTest
@testable import REACH

final class SharedContentPolicyTests: XCTestCase {
    let code = "ABCDEFGHJKLM"
    func pair(revoked: Bool = false) -> PairRecord { PairRecord(hostUid: "a", partnerUid: "b", revoked: revoked) }
    func draft() -> SharedContentDraft { SharedContentDraft(id: "entry", pairCode: code, authorUID: "a", kind: .memory, title: "A moment", text: "Words") }
    func read(_ uid: String?, pair: PairRecord?, host: String? = "ABCDEFGHJKLM", partner: String? = "ABCDEFGHJKLM") -> Bool {
        SharedContentPolicy.canRead(uid: uid, code: code, pair: pair,
                                    hostLock: host.map { MemberLockRecord(pairCode: $0) }, partnerLock: partner.map { MemberLockRecord(pairCode: $0) })
    }
    func testBothPairedMembersReadAndOutsidersAndUnauthenticatedAreDenied() {
        XCTAssertTrue(read("a", pair: pair())); XCTAssertTrue(read("b", pair: pair()))
        XCTAssertFalse(read(nil, pair: pair())); XCTAssertFalse(read("outside", pair: pair()))
    }
    func testMissingRevokedIncompleteAndMalformedPairsFailClosed() {
        XCTAssertFalse(read("a", pair: nil)); XCTAssertFalse(read("a", pair: pair(revoked: true)))
        XCTAssertFalse(read("a", pair: PairRecord(hostUid: "a", partnerUid: nil)))
        XCTAssertFalse(read("a", pair: PairRecord(hostUid: "a", partnerUid: "a")))
        XCTAssertFalse(read("a", pair: PairRecord(hostUid: "a", partnerUid: "bad/uid")))
    }
    func testBothPermanentLocksMustMatch() {
        XCTAssertFalse(read("a", pair: pair(), host: nil))
        XCTAssertFalse(read("a", pair: pair(), partner: nil))
        XCTAssertFalse(read("a", pair: pair(), partner: "MNPQRSTVWXYZ"))
    }
    func testSharingRequiresConsentToExactSnapshot() {
        let draft = draft(), lock = MemberLockRecord(pairCode: code)
        XCTAssertFalse(SharedContentPolicy.canSave(uid: "a", draft: draft, consent: nil, pair: pair(), hostLock: lock, partnerLock: lock))
        let consent = SharedContentConsent(reviewedDraft: draft)
        XCTAssertTrue(SharedContentPolicy.canSave(uid: "a", draft: draft, consent: consent, pair: pair(), hostLock: lock, partnerLock: lock))
        var edited = draft; edited.text = "Changed after approval"
        XCTAssertFalse(SharedContentPolicy.canSave(uid: "a", draft: edited, consent: consent, pair: pair(), hostLock: lock, partnerLock: lock))
        edited = draft; edited.category = "Changed audience-facing category"
        XCTAssertFalse(SharedContentPolicy.canSave(uid: "a", draft: edited, consent: consent, pair: pair(), hostLock: lock, partnerLock: lock))
        edited = draft; edited.eventAt = draft.eventAt.addingTimeInterval(60)
        XCTAssertFalse(SharedContentPolicy.canSave(uid: "a", draft: edited, consent: consent, pair: pair(), hostLock: lock, partnerLock: lock))
    }
    func testPartnerCannotWriteOrDeleteAnothersContent() {
        let draft = draft(), lock = MemberLockRecord(pairCode: code)
        XCTAssertFalse(SharedContentPolicy.canSave(uid: "b", draft: draft, consent: SharedContentConsent(reviewedDraft: draft), pair: pair(), hostLock: lock, partnerLock: lock))
        XCTAssertFalse(SharedContentPolicy.canDelete(uid: "b", draft: draft, pair: pair(), hostLock: lock, partnerLock: lock))
        XCTAssertTrue(SharedContentPolicy.canDelete(uid: "a", draft: draft, pair: pair(), hostLock: lock, partnerLock: lock))
        XCTAssertFalse(SharedContentPolicy.canDelete(uid: "a", draft: draft, pair: pair(revoked: true), hostLock: lock, partnerLock: lock))
    }
    func testPathAndPayloadValidationRejectsUnsafeInputs() {
        for id in ["", ".", "..", "x/y", "__reserved__", String(repeating: "a", count: 1501)] { XCTAssertFalse(SharedContentPolicy.documentID(id)) }
        for code in ["", "bad", "OOOOOOOOOOOO", "ABCDEFGHJK/L"] { XCTAssertFalse(SharedContentPolicy.pairCode(code)) }
        var draft = draft(); draft.title = ""; XCTAssertFalse(draft.isValid())
        draft.title = "Valid"; draft.text = String(repeating: "a", count: 6001); XCTAssertFalse(draft.isValid())
    }
}
