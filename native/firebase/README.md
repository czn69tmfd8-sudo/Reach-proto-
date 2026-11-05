# Native staging rules review — deployment blocked

**Do not deploy `firestore.rules` as the staging ruleset.** It contains only the
new native namespace and would deny existing web collections if deployed alone.
No live rules or data are changed by this directory's tests.

Run `npm ci && npm test`. The emulator uses demo projects and no Firebase login.
The suite runs the original 12 security tests against an exact `8956bb8` fixture,
then native tests against that fixture plus the new native rules. The fixture is
repository history, **not an export of the currently deployed staging rules**.
The production hosting configuration is untouched.

Native data lives exclusively under `nativeStaging/v1/{pairInvites,memberLocks,rooms}`.
There is no import, rewrite, deletion, migration, or adoption of web `pairInvites`,
`memberLocks`, `rooms`, profiles, or memories. Old pre-namespace native test records
are also left in place. New native invitations use 12 characters and expire after
30 minutes. Acceptance needs explicit action by another authenticated UID.
An accepted partnership remains authorized until revocation; invitation expiry
alone does not dissolve it.

Either locked native member may irreversibly revoke the pair. The transaction
records `revokedBy` and server `revokedAt`, clears its session pointer, and retains
both members and all historical documents. Room housekeeping is best effort and
cannot block revocation, even if a room is expired or missing. Each owner may
then atomically move only their own native lock to a fresh invitation, keeping
their Firebase identity. An active prior pair, missing prior pair, outsider,
foreign lock, reused code, or unrevoked old invitation does not permit re-pairing.

Room payloads (including SDP) and both ICE subcollections require a current,
active, unexpired room, its matching pair pointer/roles, two matching locks, and
an unrevoked partnership. Ending, expiry, or revocation denies subsequent server
reads and writes. A client can still possess previously received data; rules do
not erase caches. The app closes media at the room's expiry and observes room and
pair invalidation. Server TTL/janitor deletion is a separate retention task.
Cleanup may end an expired room without reading its protected SDP. Supplying a
mismatched pair code is rejected, and stale cleanup cannot clear a newer room.

Before deployment: obtain the **complete currently published staging rules**,
verify all web matches and broad wildcard grants, merge only the native block,
run the same tests against that exact merged artifact, and review its diff. The
visible conversation excerpt is insufficient for that final comparison. Do not
publish this native-only file or substitute the historical fixture for live rules.

After review/deployment and Anonymous Auth verification, test two installations:
A creates a native code; B accepts; both refresh; A opens a hand; B explicitly
takes it. Verify actual sound and moving video, then End, expiry, revoke, and
fresh re-pair. No automatic overnight join is enabled. Device signing and TURN
connectivity remain separate milestones.

## Additive review preparation

`prepare-rules-review.mjs` performs local review preparation only. Supply the full
exported staging source and its independently checked SHA-256, then run from the
repository root (substitute real source path/hash):

```
node native/firebase/prepare-rules-review.mjs \
  /secure/staging-export.rules native/firebase/firestore.rules \
  native/firebase/review-output reach-staging-a4745 EXPECTED_SHA256 --review-only
```

The new review directory contains the untouched baseline, native insertion,
merged source and hash manifest. The tool refuses overwrites, unsupported or
incomplete input, a non-staging target, existing native matches, and potentially
overlapping broad grants. It never calls Firebase. The manifest always says
`deploymentApproved: false` and `liveBaselineVerified: false`; hashes are not proof
that a supplied file is the current live release. Human source verification,
emulator testing against that exact merged file and explicit approval remain
required. No deployment function or command is provided.

The emulator security suite now uses this same merge function with the historical
fixture, so merge tests and authorization tests exercise the same insertion path.
This is still not a replacement for obtaining the full deployed baseline.

To exercise that exact prepared artifact with the security tests, set
`REACH_RULES_REVIEW_DIR` to the new review directory when running `npm test` from
`native/firebase`. The loader verifies baseline/native/merged hashes and rebuilds
the addition for an exact comparison before loading any rules into the demo
emulator. A changed artifact fails testing. This mode still cannot deploy or
assert that the baseline is the current live release.
