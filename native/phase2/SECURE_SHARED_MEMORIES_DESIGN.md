# Adventure Book Phase 2 — secure shared memories (development only)

**Branch:** `feature/adventure-book-phase2-secure-memories`, created from the approved application checkpoint `c76561823ce4f48f3849c59a2efff327e5e78e59`.

**Release boundary:** Build 16 remains immutable. This branch must not merge into release, deploy Firebase rules, enable photo upload, publish to TestFlight, or modify existing calling/pairing/authentication behavior without separate approval.

## Architecture proposal

- **Pair-scoped ownership:** every memory belongs to exactly one validated, currently active couple/pair. Never accept a client-supplied pair ID as proof of authorization; derive authorization from the server-validated membership and current pair lock.
- **Firestore metadata:** `pairs/{pairId}/memories/{memoryId}` with author UID, created/updated server timestamps, optimistic version, type, visibility, status, story text, optional photo references, and tombstone state. No photo bytes in Firestore.
- **Storage objects:** `pairs/{pairId}/memories/{memoryId}/{photoId}`; randomized object identifiers; exact MIME allowlist, byte limit, safe metadata; only current pair members may read. Write permissions require verified membership and a matching memory document. Deny unpaired, revoked and expired members.
- **Draft-to-published photo lifecycle:** create metadata draft; upload to a staging object; verify content type, size and ownership server-side; mark ready only after upload completion and validation. Do not expose unverified objects. Delete abandoned uploads and orphaned metadata with a bounded cleanup process.
- **Synchronization:** Firestore listeners scoped to active pair; stable ordering by server creation timestamp + document ID; local cache for offline reading; queued edits must revalidate pair membership and version before commit. Revocation immediately stops listeners and clears partner-scoped cached data.
- **Individual stories:** `myStory` and `partnerStory` are separate author-owned fields or documents; only the author may edit their own story. Both can read while pair membership remains valid.
- **Our Conversation:** append-only author-attributed messages (or revisioned messages with edit history), pair-scoped. Prevent one partner editing or deleting the other's messages.
- **Deletion:** explicit tombstones and authorized object cleanup; define behavior for unpairing, account deletion, and shared-memory retention before deployment.
- **Limits:** image size, per-pair quotas, pagination, rate limits, and retry/backoff. Photos must not be uploaded until server rules and tests pass.

## Security test matrix

1. Paired A/B can create and read shared memory metadata; unrelated C cannot read or enumerate.
2. A can edit A's story, not B's; B can edit B's, not A's.
3. A cannot author messages as B, edit B's conversation entries, or change server-owned timestamps.
4. Expired or revoked membership rejects reads, writes, and Storage operations.
5. Concurrent edits use version preconditions: exactly one succeeds; stale edits fail.
6. Storage rejects oversized uploads, invalid MIME types, wrong paths, and cross-pair reads.
7. Metadata cannot publish a nonexistent/unverified photo; orphan cleanup is safe.
8. Offline queued changes are rechecked on reconnect and fail closed after revocation.
9. Pagination and listener restarts avoid duplicate or missing memories.
10. Existing audio/video, pairing, and authentication regression suites remain green.

## Implementation sequence (no deployment)

1. Define a pure Swift domain model with validated memory IDs, content limits, versioned edits, and ownership decisions.
2. Add unit tests for authorization decisions and merge/conflict behavior without Firebase.
3. Implement a Firestore adapter behind a protocol, disabled by default.
4. Draft Firestore and Storage rules in separate staging-only proposal files; run emulator tests with synthetic accounts before seeking approval.
5. Add upload queue and photo validation behind a disabled feature flag.
6. Integrate into the approved Adventure Book UI only after review, preserving its visual fidelity.
7. Request explicit authorization for any Firebase rule deployment, real upload, merge or TestFlight distribution.

## Release infrastructure

The existing signed Build 16 IPA and Codemagic artifacts remain untouched. The release procedure is maintained separately at `native/release/ADVENTURE_BOOK_UPLOAD_PROCEDURE.md` on `release/adventure-book-archive-preparation`. Investigate artifact transfer independently; do not create additional release workflows until a verified need exists.
