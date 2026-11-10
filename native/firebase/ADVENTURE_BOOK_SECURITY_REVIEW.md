# Adventure Book security review — NOT DEPLOYED

## Status
The Firestore and Storage rules are proposed staging-only contracts. CI emulator tests must pass before implementation can be treated as validated. Existing production and pairing are untouched.

## Access and revocation
- The rules consult the current native staging pair invitation, both member locks and the revoked flag on each protected request.
- Revocation changes authorization only; it does not delete Firestore memories, stories, comments, metadata or Storage objects.
- The present rules do not implement invitation expiry as a session expiration: an accepted, non-revoked pairing remains valid even if the original invitation's `expiresAt` has elapsed. If time-limited shared access is desired, a separate active-access expiry must be specified and enforced.
- A cached Firestore snapshot or a file already downloaded to a device cannot be remotely erased. Client UI should clear local previews when revocation is observed, but a disconnected or compromised device may retain old bytes.
- **Firebase Storage download URLs can carry long-lived download tokens and bypass subsequent authenticated Storage Rules checks.** Never persist, display, export or share `getDownloadURL()` links for private memories. Prefer authenticated SDK `getData` reads, avoid caching sensitive bytes to disk, and avoid generating bearer URLs. Previously issued URLs must have their object download tokens rotated/revoked separately; changing rules alone is insufficient.
- Photos shared outside the app or included in an exported physical book cannot be recalled.

## Concurrency and uploads
- Each partner's story has its own document keyed by their UID. Backend rules reject edits to the other partner's story.
- **Rules alone do not implement compare-and-swap**. Story edits must use server updateTime preconditions or transactions, reject stale versions, and explicitly surface conflicts. Client timestamps are not a concurrency substitute.
- A photo upload uses a new random object ID, immutable create-only Storage permission, a maximum of 15 MiB, a constrained MIME type, and authenticated owner metadata. MIME labels are not content verification; verify image bytes and safe decoding on the client and optionally server-side before publication.
- Upload first, verify, then create photo metadata. Interrupted uploads can leave orphan objects. A future privileged cleanup process must only delete verified unreferenced objects after a grace period, with a durable audit trail. Do not expose generic client overwrite/delete privileges.
- **Intentional deletion is not yet implemented.** Current proposed Firestore and Storage rules deny delete, which protects against accidental destruction but does not satisfy the final deletion workflow. Implement a separately authorized, auditable deletion request and privileged cleanup after both storage and metadata references are reconciled. Revocation must never trigger this workflow.

## Acceptance gates
1. CI emulator tests for two couples, revocation, locks, author ownership, comments and metadata.
2. Storage emulator tests for object read isolation, ownership, size, MIME and immutability.
3. Real server version-precondition conflict tests and interrupted-upload recovery.
4. Independent review of rule evaluation costs and the staging-only rollout.
5. Explicit user approval before staging rule deployment; no production deployment.
