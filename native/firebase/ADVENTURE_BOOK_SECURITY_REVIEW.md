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

## 500-memory quota migration candidate

The emulator-only quota test overlays a candidate on the reviewed Firestore
fixture in memory. It never supplies rules to the normal merge or deployment
path. A quota document per pair stores an integer count and the ID of the last
memory created. Each new memory and its one-slot increment are in the same
atomic write. Rules check both before and after state, bind the increment to the
one new document, keep the existing membership checks, and reject standalone
creates and client-created quota documents. A retry of an existing matching ID
uses its original slot. A losing transaction may receive permission denied
before the SDK retries. Only report a full book after an authorized server
reread confirms the cap. Story and photo metadata writes are outside this quota.

An authorized rollout needs a creation freeze before a privileged inventory and
backfill. Count actual documents, including older IDs, reconcile books already
above 500 without deleting user data, and verify quota totals against inventory
before enabling creation. Missing quota documents must fail closed for new
writes. Legacy clients can continue existing memory access under current
authorization, while new creation requires the quota-aware client after cutover.
Privileged writers and restore paths must maintain the same invariant because
they are outside client-rule enforcement. Exercise the cutover and rollback
against synthetic data before considering staging.

## Photograph authorization proposal

The direct Storage rules candidate depends on four distinct Firestore documents
per request: the pair invitation, two member locks, and the memory. Firebase
documents a two-document budget for Storage rule evaluation. Emulator success
does not establish that the existing candidate fits that hosted budget.
[Firebase Storage rule conditions](https://firebase.google.com/docs/storage/security/rules-conditions)

The first release can retain the disabled photo gate. When real photographs are
required, use one authenticated service for both uploads and reads. It should
verify the caller's Firebase ID token, derive the UID from that token, read the
pair invitation, both member locks and the requested memory in a consistent
Firestore snapshot, and fail closed if any authority is absent or mismatched.
The service derives object names from validated IDs and uses narrowly scoped
IAM on a private bucket. Its authenticated endpoint streams bytes and does not
issue reusable download links. A mirrored membership document would require
every pairing and revocation writer to update it atomically, including older
clients, before it could be an authoritative alternative.

Reserve a stable photo ID, enforce byte and decoded image limits, and create an
immutable object using a generation precondition. In the same Firestore
transaction that publishes metadata, recheck current membership and the
memory, and bind publication to the verified object generation. Retry without
replacing existing data. Reauthorize every read against current membership and
published metadata. Revocation denies new requests after it takes effect.
Bytes already delivered cannot be withdrawn.
An interruption between object creation and metadata publication can leave an
unpublished object for a separately reviewed cleanup procedure.

Activation requires explicit approval for the service and IAM, review of direct
bucket access and any existing download tokens, and a Firestore rules migration
if metadata publication is restricted to the service. Before opening either
gate, validate partner access, cross-couple denial, revocation, missing or changed
locks, overwrite denial, interrupted uploads, and metadata recovery with
synthetic accounts in an authorized hosted staging environment.
