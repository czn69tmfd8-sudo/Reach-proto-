# Proposed shared relationship content — NOT DEPLOYED

The live application remains local-first. `RelationshipJournalStore` has no
Firebase or network dependency. Private journal entries and memory photos are not
converted or uploaded. This directory is not referenced by firebase.json, deployment
scripts or Codemagic publishing. Never deploy this standalone rules file: it grants
no existing pairing/calling writes. A future additive merge needs a separate review,
owner approval and a complete emulator run against the exact merged artifact.

## Smallest proposed schema

`nativeStaging/v1/coupleContent/{pairCode}/items/{entryID}` has one bounded text-only
collection for `memory`, `question`, `response` and `dateIdea`. Required fields:

| Field | Contract |
| --- | --- |
| kind | One of the four supported kinds; immutable |
| authorUid | Authenticated creator; immutable |
| title / text | Nonempty title <=120 characters; text <=6000 |
| eventAt | User-chosen timestamp |
| category / status | Category <=40 characters; saved/planned/completed/dismissed |
| questionId | Existing question ID in the same pair for a response; otherwise null; immutable |
| createdAt | Server time at creation; immutable |
| updatedAt / consentedAt | Server time for every create/update |

No image blobs, URLs, public profiles, contact lists, read receipts, online-presence
claims or recordings. Photos remain private until a separately approved Storage
path, rules, content-type/size validation and deletion pipeline exist. Daily
reminders and milestones remain local initially. Questions and responses are
separate authored items: a partner can read but cannot overwrite/delete the other
member's response. Query only the known pair's items; no cross-pair collection-group
query is authorized.

Every read/write checks authentication, valid pair path, existing complete pair,
non-revoked state and BOTH permanent member locks. Invites have a 30-minute joining
expiry; accepted relationships are not expired by the old invitation deadline.
Content authorization is independent of a room being open. Native room expiration
and consent restrictions remain in the existing calling rules unchanged.

## Consent and deletion

A future sharing interface must show a complete preview, selected pair, author,
fields and audience. No bulk migration or automatic sharing on pairing. The
non-network Swift `SharedContentConsent` binds consent to the exact draft snapshot;
edits require renewed review. Timestamp receipts in rules are validation, not proof
that a human tapped consent. The actual sharing UI, Firestore serialization, server
clock handling and revocation listener are NOT implemented and sharing is disabled.

Only the author may edit or delete while the pair is authorized. A deleted question
can leave separately authored responses; it does not delete the partner's writing.
Those responses remain readable to the authorized pair, but cannot be edited until
their question exists; authors can still delete them. A production deletion design
must decide whether this retention is acceptable before activation.

Revocation denies further server access, including former-author deletes. Previously
read/exported data cannot be recalled by Firestore rules. Before sync activation,
implement ephemeral shared caches with disk persistence disabled, listener teardown
and cache clearing on revocation/sign-out; never store them in the private journal.
Provide an approved authenticated deletion request process for inaccessible former
pair data, retention limits, account deletion and restore/backup behavior. These are
activation blockers, not capabilities supplied by this draft.

## Tests

`native/firebase/sync-proposal.test.mjs` uses a demo-only project and requires a
loopback Firestore emulator. Seven scenarios cover paired/unauthenticated/outsider
access, revocation, missing/malformed documents and locks, owner-only mutation,
validation/consent receipts, responses, and isolation from existing native/web
paths. It is included in the existing emulator suite's *.test.mjs discovery, but
has NOT been executed here. Existing emulator access was blocked by automatic
approval review; no retry or bypass was attempted. Node syntax checks are not rules
execution. Swift pure-policy tests cover exact-snapshot consent, field/path bounds,
membership, both locks and owner-only edits/deletion; they also await a Swift runner.
