# Adventure Book incomplete-photo cleanup proposal (review only)

**Status:** no client deletion, no security-rule modification, no deployment.

## Problem
An immutable Storage object can exist without its Firestore photo document after a crash or a rejected metadata commit. A local journal is not authoritative: it may be deleted, another device may publish the object, or an upload may complete after the client disconnects. Never delete solely because a client reports an orphan.

## Proposed authorized cleanup
1. Create a privileged, authenticated **staging-only** cleanup endpoint, not a Storage `allow delete` rule. It must use verified Firebase Auth, app integrity checks where available, and explicit operator-controlled deployment approval.
2. Accept only `pairCode`, `memoryID`, `photoID`, and expected Storage `generation` / `metageneration`; reject arbitrary paths. Reconstruct the canonical object path on the server.
3. Confirm the caller is the object's owner and the pair's current member-lock/invitation state permits a cleanup request. Revocation must not authorize deletion; send revoked orphan requests to an administrator-reviewed queue.
4. Verify object metadata (ownerUid, JPEG type, SHA-256, creation timestamp, generation). Verify the parent memory and absence of any published photo document. Check for an in-flight publish lease and a minimum retention period (proposed **7 days**, subject to review).
5. Recheck document absence and object generation immediately before a conditional Storage deletion. A race must fail closed; no unconditional delete. Never delete a published photo as part of orphan cleanup.
6. Write a durable audit record with requester UID, pair, memory/photo IDs, reason, authorization decision, object generation/hash, timestamps, result and server actor. Avoid storing raw image bytes or bearer download tokens.
7. Run dry-run inventory first, require explicit approval for real deletion, and use staged batches with quotas. Log and alert on unexpected rates. Storage deletion is not generally reversible; where supported, configure object versioning/retention and verify cost implications before enabling.
8. Keep client rules `allow delete: if false` for both Storage objects and photo metadata. A separate consent-driven **published photo deletion** feature needs its own ownership, partner-consent, retention and audit design.

## Emulator/security test plan
- Owner eligible orphan after retention: dry-run reports eligible; approved privileged actor deletes exact generation and records audit.
- Wrong owner, outsider, revoked pair, invalid locks, invalid path: deny; object remains.
- Published metadata, metadata appearing during cleanup, upload still in progress: deny; object remains.
- Object replaced or generation changed between inspection and deletion: conditional delete fails.
- Duplicate cleanup requests: idempotent audited outcome; never delete another object.
- Privileged endpoint unavailable: client retains journal and does not attempt direct deletion.
- Existing 11 Firestore/Storage security tests plus all new recovery/cleanup tests must remain passing.

## Rollback and approval boundary
Do not deploy this endpoint, grant new IAM permissions, enable billing or retention/versioning, or change Firebase rules without separate explicit approval. No cleanup is executed by this proposal.
