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

## First-release decision and Firebase-only photo alternatives

| Approach | Revocation and isolation | Authorization and shareable links | Compatibility and operating cost |
| --- | --- | --- | --- |
| Keep photos gated off | Existing Adventure Book authorization stays in force. | No new photo upload or retrieval path opens. | Lowest migration and operating cost. First release contains stories and comments. |
| Bounded private image payloads in Firestore | Each server read and write checks the pair, both member locks and the memory. Cross-couple reads and writes are denied. | No Cloud Storage lookup budget or download URL. Exact owner, immutable IDs and a 256 KiB limit are exercised in the emulator. | Reuses Firestore and Auth with no hosted service. Requires a new payload transport, metadata integration and a cache review. Small compressed images only. Firestore storage, reads and transfer still cost money. |
| Direct Firebase Storage with one authoritative pair document plus the memory | Can fit two lookups only if the consolidated pair record is authoritative and every pairing, lock and revocation writer updates it atomically. A delayed mirror is unsafe. | Storage rules must protect both upload and download. Authenticated SDK reads alone do not prove that a member cannot obtain a long-lived bearer URL. | Closest to the current transport, but requires a pairing migration, older-client cutover and hosted proof that token URL creation and retrieval cannot bypass revocation. |
| Authenticated photo service with private Storage | Checks current pair, both locks and memory on each request. Metadata publication rechecks authority transactionally. | Authenticated byte delivery and no bearer URL issuance. IAM and existing token exposure must be reviewed. | Supports the existing full-size image goal. Requires a transport change, compute and transfer costs, monitoring and orphan cleanup. A Firebase-managed function is still a hosted service. |

The Firestore payload test is an emulator-only policy sketch, not a release
transport. Keep the blob separate from gallery metadata so list queries never
pull image bytes. A real candidate needs an indexing exemption for the blob, a
per-book or per-memory image budget, bounded decoding and client-side re-encoding,
and coordinated publication and retry handling for metadata and payloads. The
rules test only the byte type and size, not whether the bytes form a valid image.
Apple Firestore normally uses persistent caching. A production image transport
must prove that payloads are never served from an offline or stale client cache
after authorization changes, and review durable local copies before rollout.
Revocation applies to new authorized requests. Bytes already delivered to a
device cannot be recalled.

[Firestore size limits](https://firebase.google.com/docs/firestore/storage-size)
[Firestore offline caching](https://firebase.google.com/docs/firestore/manage-data/enable-offline)
[Firebase Storage Apple SDK and download tokens](https://firebase.google.com/docs/reference/swift/firebasestorage/api/reference/Classes/StorageReference)

## Quota cutover and rollback checklist

1. Approve a creation freeze that covers every old and new memory writer,
   including privileged jobs. Keep existing reads and edits available. Verify
   the freeze in staging using an old client and a quota-aware synthetic client.
2. Export a recovery snapshot and inventory actual document counts per couple.
   Keep any over-limit books intact and creation disabled for those pairs.
   Backfill one verified counter per pair. Provision new pairs through a trusted
   path before their first memory. Keep a count and discrepancy log without
   copying story content into the migration report.
3. Verify counts independently while creation is frozen. Reconcile missing or
   mismatched counters before enabling writes. Roll out the quota-aware app
   and the reviewed rules together. Verify old-client creates are denied,
   existing edits still work, and a concurrent final-slot test reaches 500.
4. If the rollout fails, return to the creation-freeze policy. Preserve
   counters and documents created since cutover. Do not restore an earlier
   ruleset that allows uncounted creation or overwrite data with the pre-cutover
   snapshot. Repair the client or reconcile counters against current inventory
   while frozen, then repeat the final-slot and retry checks before resuming.

The emulator exercises freeze, synthetic backfill, enforcement, rollback to
freeze and reopening with existing memories and counters preserved. Live rule
deployment, inventory, app migration and photo activation require separate
approval.

## Quota-aware client and migration rehearsal

The iOS repository can reserve the final slot and create the memory in one
transaction. The staging activation constant defaults off. When enabled in a
separately approved build, a missing counter blocks new creation, an existing
matching memory ID retries without consuming a slot, and a rejected write only
reports a full book after authorized server reads confirm a full counter and an
absent attempted memory. The initial story follows the existing retryable
second-write protocol.

Run `node native/firebase/adventure-book-quota-plan.mjs INVENTORY.json` with a
frozen inventory captured by an authorized operator. Input is an object with
`creationFrozen: true` and a `books` array containing `pairCode`,
`memoryCount`, and optional `existingQuota`. The planner prints a review-only
JSON plan. It has no Firebase dependency, credentials, or write mode. Its freeze
flag records the operator's input and cannot verify a real freeze. Missing
counters for in-limit books receive proposed initial values. Drift and
over-limit books require explicit reconciliation and receive no proposed write.

Before staging approval, assemble and review the exact frozen and enforced
rules, verify every writer participates in the freeze, inventory and rehearse
the plan with synthetic accounts, and approve an operator and rollback owner.
After separate authorization, rehearse a hosted staging cutover, verify old
clients cannot create uncounted memories, and exercise competing final-slot
writes and repeat IDs. Roll back to the creation freeze and reconcile from
current data before reopening. Preserve existing memories and post-cutover
writes. Live inventory, applying counters, publishing rules, enabling the
quota-aware client, and distributing any build each require release approval
covering the intended environment and step.

## Bounded photo prototype and travel-photo measurements

The emulator prototype stores the bytes, owner, operation ID and timestamp in
one immutable document per memory, so metadata cannot commit independently of
the payload. An identical retry adopts the original document. A conflicting
retry, extra slot, list query, cross-couple access, or revoked access is denied.
Photo reads require a server response in a Node emulator client using in-memory
state. The native app includes a local encoder and does not call this prototype
transport. No live photo gate or scrapbook view is changed.

One preview per memory limits stored payloads to 125 MiB per full 500-memory
book before document overhead. A proposed eight-card gallery reads at most
eight preview documents, or 2 MiB before protocol overhead, per complete spread
fetch. Reopening a spread can incur another set of reads. Prefer lazy visible
card fetches, cancel offscreen requests, and keep any byte cache session-only.
The hosted read and write cost, cache behavior on iPhone, and index exemptions
for the bytes field need validation before activation.

A Pillow JPEG experiment used the same 1,280 px initial edge and quality
ladder as the iOS encoder. These numbers are the local comparison, not Apple ImageIO
codec measurements. The native CI benchmark runs the same ImageIO encoder
as the iOS prototype and prints byte counts and dimensions for the four
checksum-pinned travel inputs. PSNR compares identically cropped versions of the source
and encoded result at the stated display sizes.

| Photo | Input bytes | Output bytes | Output pixels | Gallery 360×220 | Detail 720×440 |
| --- | ---: | ---: | --- | ---: | ---: |
| Starry mountains | 466,535 | 230,815 | 1280×854 | 45.8 dB | 42.8 dB |
| Neon street | 329,506 | 156,186 | 1280×853 | 43.4 dB | 39.3 dB |
| Paris skyline | 318,242 | 160,942 | 1280×851 | 46.2 dB | 42.8 dB |
| Woodland and cliffs | 1,230,707 | 254,165 | 775×1280 | 38.2 dB | 33.5 dB |

All four fit 256 KiB at the first quality step. At gallery size the paired
crops looked close, with the most measurable loss in the dense woodland
sample at detail size. The native test uses a synthetic image to validate
decoding, bounds and aspect ratio. Before photos advance, repeat the travel
quality comparison on iPhone, include GPS-bearing and rotated originals,
verify re-encoding strips source metadata, and test real-device cache and
revocation behavior with synthetic accounts. Photos still require explicit
approval for hosted rules, authenticated native transport, budget controls,
and gate activation.

[Mountains](https://images.unsplash.com/photo-1519681393784-d120267933ba?w=1800)
[Night street](https://images.unsplash.com/photo-1519608487953-e999c86e7455?w=1800)
[Paris](https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=1800)
[Woodland](https://images.unsplash.com/photo-1472396961693-142e6e269027?w=1800)

## Native private-preview transport candidate

The gated native adapter uses Firebase ID tokens with Firestore REST requests.
It uses an ephemeral URLSession with no HTTP cache, cookies, credentials store,
redirects or offline fallback. This keeps photo bytes outside the Firestore
SDK document cache. The fixed preview path, create-only precondition and
server timestamp keep metadata and bytes together. A retry after an uncertain
commit must fetch the exact same owner, deterministic byte digest and bytes.
Re-encoding different bytes cannot overwrite an existing preview.

The gallery requests only IDs on the visible spread, up to eight documents,
and downsamples decoded images to at most 400 px per edge for cards. The
detail view fetches one preview. The scope key discards stale responses when
changing spreads, opening details, backgrounding or reconnecting. The auth
listener and current pairing/member-lock observations invalidate the private
session on observed access loss. Re-entry fetches fresh server data. A preview
uploaded on the other device appears on a subsequent scope fetch; the native
candidate does not continuously subscribe to the image-byte documents.
Auth/pair observation adds its own small metadata read budget, separate from
the eight preview reads. The full 2 MiB payload budget excludes base64 and
protocol overhead.

Before hosted use, validate both devices with synthetic accounts, including
network loss during an upload, partner revocation while a spread is visible,
relaunch, foreground transitions, on-device memory use and disk/cache
inspection. Confirm the exact REST call shape, any App Check requirements,
and metered authorization read costs in the intended staging environment.
App Check, if enforced for this database, needs an explicitly reviewed
authenticated header path before activation. Existing live photo and quota
settings remain closed. The offline quota planner and freeze/backfill/rollback
rehearsal remain the starting point for the separate quota cutover decision.

For a read-only post-backfill check, pass the reviewed pre-backfill inventory
and the independently collected post-backfill inventory to the quota planner.
It reports missing, unexpected or changed books and any unverified quota, and
exits nonzero on discrepancies. Both snapshots must declare the same creation
freeze window operationally. The tool verifies counts and roster equality, not
the actual live freeze or the completeness of the operator's source export.
