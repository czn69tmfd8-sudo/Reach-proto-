# REACH secure pairing recovery — backend contract (staging only)

Status: DESIGN / NOT DEPLOYED. No production database or security rules are changed.

## Threat model
A pair code, saved local UID, profile photo, browser checkbox, or client-provided `verifiedByTrustedBackend` flag is **not** identity proof. An attacker with a leaked code or access to one phone must not be able to hijack a pairing. Anonymous Firebase accounts cannot by themselves prove that a new anonymous UID belongs to the same person as an old one.

## Prerequisites
1. Enroll **both existing members** in independently recoverable credentials while their existing sessions are still trustworthy (Firebase Auth email-link or passkey-based identity, with explicit reauthentication). If either old identity is lost before enrollment, use a separate human-reviewed recovery process; never silently auto-reassign a pair.
2. Backend runs with a dedicated Firebase Admin SDK service identity. Clients must not write recovery approvals or alter `hostUid`, `partnerUid`, or `memberLocks`.
3. Explicit consent on both authenticated devices; clearly display partner identity, target account and exact pairing. Expire each approval in <= 15 minutes; use single-use, unpredictable server-issued challenge IDs.

## Proposed callable endpoints (not implemented)
- `beginRecovery`: requires authenticated identity, enrolled credential, App Check, rate limits; generates server-side challenge tied to pair ID and candidate replacement UIDs; returns opaque challenge ID.
- `approveRecovery`: verifies a **fresh** reauthentication proof for the enrolled member; records a server-side signed approval for the exact challenge and role. Never accepts client-supplied `hostVerified` or `partnerVerified` as proof.
- `commitRecovery`: server validates both distinct approved principals, challenge freshness, no revocation, no active room, matching old member identities, and both new accounts free of locks; performs atomic Firestore transaction.

## Atomic commit outline
In one transaction: read challenge, pair document, both old identity bindings and new member locks. Verify all conditions again (not from stale browser state). Create the new UID locks, update pair hostUid/partnerUid, remap each photo key without altering photo bytes, and mark challenge consumed. Record audit event in the same transaction. Preserve existing old locks as immutable historical records and ensure no old UID can act as current member. Never delete existing pair or photos. Fail closed on any conflict; do not partially commit.

## Security rules
Keep ordinary client rules immutable for identity/lock fields. Server Admin SDK bypasses rules, so enforce authorization and validation **in server code**. Restrict challenge and audit collections from client writes. Carefully review existing pair document schema (including legacy empty-string `activeRoom`/`openedBy`) and room lifecycle before deployment. Test with Firebase Emulator Suite.

## Required tests before rollout
- Both roles approve; one role missing; replay; expired challenge; mismatched challenge/pair/UID; wrong credential; revoked pair; active room; already locked new UID; simultaneous commit race; attempted cross-pair hijack; stale session; photos preserved; audit persisted; old UID access denied; rollback on failure.
- End-to-end emulator tests against actual Firestore rules and Admin transaction.
- Backup production pair document and rules before any approved rollout, with restoration plan.

## Deployment gate
Do not enable or deploy recovery until both partners have usable recovery credentials and tests pass. Do not manually edit production pair UIDs, create memberLocks for an existing pair, relax Firestore rules, or re-pair phones as a workaround.
