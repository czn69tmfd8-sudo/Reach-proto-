import Foundation

/// Non-deployed contract only. There is deliberately no Firestore writer or
/// automatic conversion of private journal entries into shared documents.
struct SharedContentDraft: Equatable, Sendable {
    enum Kind: String, Sendable { case memory, question, response, dateIdea }
    let id: String
    let pairCode: String
    let authorUID: String
    let kind: Kind
    var title: String
    var text: String
    var questionID: String?
    var eventAt = Date()
    var category = ""
    var status: RelationshipEntry.Status = .saved
    func isValid() -> Bool {
        SharedContentPolicy.documentID(id) && SharedContentPolicy.pairCode(pairCode)
            && SharedContentPolicy.documentID(authorUID)
            && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && title.utf8.count <= 120 && text.utf8.count <= 6000 && category.utf8.count <= 40
            && eventAt.timeIntervalSince1970.isFinite
            && (kind == .response ? questionID.map(SharedContentPolicy.documentID) == true : questionID == nil)
    }
}

/// Consent is bound to a reviewed snapshot, so an edit or a new pair invalidates it.
struct SharedContentConsent: Equatable, Sendable {
    let reviewedDraft: SharedContentDraft
}

enum SharedContentPolicy {
    static func documentID(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 1500 && !value.contains("/")
            && value != "." && value != ".." && !(value.hasPrefix("__") && value.hasSuffix("__"))
    }
    static func pairCode(_ value: String) -> Bool {
        value.utf8.count == 12 && value.allSatisfy { "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".contains($0) }
    }
    static func canRead(uid: String?, code: String, pair: PairRecord?, hostLock: MemberLockRecord?, partnerLock: MemberLockRecord?) -> Bool {
        guard let uid, documentID(uid), pairCode(code), let pair,
              documentID(pair.hostUid), let partner = pair.partnerUid, documentID(partner),
              pair.hostUid != partner, pair.contains(uid: uid), pair.revoked != true else { return false }
        return hostLock?.pairCode == code && partnerLock?.pairCode == code
    }
    static func canSave(uid: String?, draft: SharedContentDraft, consent: SharedContentConsent?,
                        pair: PairRecord?, hostLock: MemberLockRecord?, partnerLock: MemberLockRecord?) -> Bool {
        draft.isValid() && uid == draft.authorUID && consent?.reviewedDraft == draft
            && canRead(uid: uid, code: draft.pairCode, pair: pair, hostLock: hostLock, partnerLock: partnerLock)
    }
    static func canDelete(uid: String?, draft: SharedContentDraft, pair: PairRecord?,
                          hostLock: MemberLockRecord?, partnerLock: MemberLockRecord?) -> Bool {
        uid == draft.authorUID && canRead(uid: uid, code: draft.pairCode, pair: pair, hostLock: hostLock, partnerLock: partnerLock)
    }
}
