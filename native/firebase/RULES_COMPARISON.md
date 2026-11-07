# Staging compatibility review

## Evidence and limits

The working baseline for native iOS is `ec33db5`: Codemagic build 7 passed all
71 native tests, including WebRTC SDP negotiation and Keychain I/O. This is not
evidence of live Firebase authorization or a two-device media call.

The visible excerpt of the user's deployed rules defines `signedIn`, `pairPath`,
`pairExists`, `pairData`, `pairMember` and the beginning of `roomMember`. In that
excerpt, `pairMember` requires a non-null partner, unrevoked pair membership, and
**allows a missing caller membership lock** (`!exists(lockPath(uid)) || lockMatches`).
The complete supplied source is not available in the current context or retrieved
conversation results. Older assistant-proposed rules are not treated as deployed
source. Therefore full deployed-rule compatibility remains **unverified**.

The historical fixture is copied byte-for-byte from
`8956bb8:native/firebase/firestore.rules`. SHA-256:
`0f18c159fab30af407c618ca57a23caa35408462faa83528fddd7a135b3aef03`.

| Concern | Visible deployed excerpt | Commit 8956bb8 | Native candidate |
| --- | --- | --- | --- |
| Web membership locks | Missing caller lock allowed | Both locks mandatory | Web unchanged; both locks mandatory only in native namespace |
| Collection scope | Shared web collections | Shared web collections | `nativeStaging/v1` only |
| Fresh pairing | Full write clauses unavailable | One lock per UID, permanent | Fresh native code; existing web data not adopted |
| Re-pairing | Full clauses unavailable | Client lock update/delete denied | Owner can replace own native lock only after prior pair revoked |
| Invitation expiry | Unavailable | No invitation deadline | Acceptance deadline of 30 minutes |
| Revocation | Pair membership rejects revoked pairs | Revocation flag, no audit fields | One-way revoke with actor/server timestamp and cleared pointer |
| Room read expiry | `roomMember` body incomplete | Room get did not check expiry | Room payload and ICE reads/writes require active, current, unexpired authorization |
| Retention | Unavailable | No automatic deletion | No deletes; inaccessible history retained |

## Emulator coverage

The original 12 tests run against the historical fixture. Native tests run in a
separate emulator demo project with the unchanged historical web block plus the
native block, exercising re-pairing, revocation audit, concurrent claims/openings,
expired SDP/ICE read and write denial, stale cleanup, invalid updates, and exact
preservation of seeded web documents (including custom fields/photos/candidates).
These prove isolation against the repository baseline, not an unseen live ruleset.

## Deployment gate

No deployment command is executed or provided as a next step here. Review the
complete deployed staging source, including all wildcard matches and unrelated
web collections, before creating a deployable merged ruleset. Re-run tests against
that exact artifact and inspect the diff. Never replace it wholesale with either
`firestore.rules` or the `8956bb8` fixture. Main, production Firebase and web code
remain outside this change.
