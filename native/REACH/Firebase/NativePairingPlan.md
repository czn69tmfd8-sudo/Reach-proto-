# Native staging pairing

Native uses `nativeStaging/v1/pairInvites`, `nativeStaging/v1/memberLocks`, and
`nativeStaging/v1/rooms`. Existing web collections and records are never imported,
modified, deleted, or adopted as native authorization. Firebase anonymous auth
persists the installation identity; revocation/re-pairing does not sign out or
manufacture a new identity.

Create and accept atomically write the caller's native lock. Only the lock owner
can replace it, and only after their existing native pair is revoked. Missing,
active, or foreign prior pairs fail closed. Invitations expire after 30 minutes;
accepted partnerships stay authorized until revoked. Revocation records the
actor/server time and clears the session pointer, and cannot depend on reading a
possibly expired/missing room. Historical pair records remain immutable.

The Staging tab provides create, accept, status/expiry, revoke, and re-pair actions.
Opening or taking a hand is explicit. Rooms and ICE require both current locks,
unrevoked membership, matching roles/current pointer, active status and expiry.
The client stops media at room expiry and reacts to pair/room invalidation.
Cleanup updates the immutable expected pair code without reading protected SDP;
rules reject cross-pair writes and stale clearing of a newer pointer.

See `native/firebase/RULES_COMPARISON.md` for evidence, tests and the deployment
gate. The native-only candidate cannot replace the deployed staging rules. No
rules are deployed by this change.
