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
