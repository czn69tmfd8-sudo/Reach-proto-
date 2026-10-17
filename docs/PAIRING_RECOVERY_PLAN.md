# REACH production pairing recovery — investigation and safe procedure

Status: INVESTIGATION ONLY. Do not deploy a repair or change production Firestore rules without verified ownership and testing.

## Confirmed from read-only screenshots (2026-10-17)
- Existing pairInvites document: VR5VUZFHPWMQ.
- Stored hostUid: MKkWabfX70VPoEhsM2vnCiiRdMm1.
- Stored partnerUid: EflcyNjVHsYACPi5jzOKzH2Cvsw2.
- New authenticated UIDs reported on two phones: j9ubPOPJnyd6SmVr3d0aYiyLX2g2 and JvcGfP2zATzxZgaBUoOjqHyCkf22.
- Both devices report missing memberLocks and pair record permission-denied.
- Pair record includes profilePhotos keyed by the old identities.
- Original pairing record still exists. No evidence it was deleted.

## Root cause and security implications
Current Firestore pairInvites get rules only allow the host or partner UID on a completed pair, subject to matching memberLocks. The new anonymous identities are neither UID, so reads fail. Existing memberLocks create rules only permit atomic creation during creation or joining of an *unpaired* invite; they do not support retroactive locks for a completed legacy pair. Simply adding memberLocks for the new identities or changing hostUid/partnerUid in the console would be unsafe and leave photos/rooms out of sync.

## Required before implementation
1. Preserve the production Firestore document and its photos; record a secure backup/export with owner authorization.
2. Confirm the Firebase project is reach-prototype-d70ef (not staging).
3. Verify which human owns each new and old UID, through a trustworthy independent process; do not treat knowledge of a pair code or localStorage alone as proof of ownership.
4. Review production authentication lifecycle and browser storage behavior. Anonymous auth may change when Safari storage is cleared or the web context differs.
5. Design an authenticated, time-limited, one-use, two-partner-approved recovery path using privileged backend code (Cloud Functions/Admin SDK) that validates both approvals, checks the old pairing is active and unrevoked, and atomically migrates the host/partner IDs, photos keys and lock records while guarding against replay/concurrent updates.
6. Preserve/reconcile active rooms; ideally require both devices to end sessions before migration. Decide whether recovery is allowed if old identity can no longer authenticate; use additional owner verification in that case.
7. Test in reach-staging-a4745 with synthetic data, including unauthorized claim attempts, expired approvals, one-party approval, duplicate claims, and rollback behavior.
8. Deploy only after user review and both partners explicitly approve the production recovery.

## Immediate instructions
- Do not manually edit UID fields, remove photos, relax Firestore rules, delete records, or re-pair.
- Keep browser website data intact on both devices.
- Production and staging are separate Firebase projects; avoid cross-project fixes.

## Code observation
Production index.html invokes signInAnonymously(auth), verifies memberLocks before live pairing, and reconciles local saved pair codes from a lock when present. Missing locks block connection even after read permissions are resolved.
