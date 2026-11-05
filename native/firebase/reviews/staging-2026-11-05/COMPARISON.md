# Additive staging rules review — approval pending

The owner supplied the complete currently deployed REACH staging rules in the
conversation on November 5, 2026. `baseline.rules` records that supplied source
(final newline normalized); the fixture is identical. This is an owner-attested
baseline, not an independently downloaded Firebase release. No rules have been
deployed, no production configuration changed, and no live web data read/written.

## Exact artifact

Target: **reach-staging-a4745**, default Firestore database only.

| Input/output | SHA-256 |
| --- | --- |
| Owner-supplied baseline | `63f06d53574e186e933c8629099439f94d554798322363eaad5edb0d1a1bfeeb` |
| Native-only candidate | `5cb57b5267054dc3423ad831c7d0ff8f1ea14313a659715b137fbb91dacd3ec1` |
| Full additive `merged.rules` | `e79d68ef918dc822a16d43af9be1106fa818d4d729cdd0b01ff94343890503fb` |

The merge inserts one scoped `match /nativeStaging/v1` before the documents-root
closing brace. Removing `native-addition.rules` reproduces the original baseline
byte-for-byte. Every original function, allow, match, comment and default-deny
clause is retained. The only recursive root match is literal deny; it does not
grant access to the native namespace. Native helpers resolve only namespaced
paths. There is no migration, TTL configuration, janitor, deletion or deployment.

## Contract comparison

| Behavior | Existing web roots, unchanged | Added nativeStaging/v1 |
| --- | --- | --- |
| Pair records | `pairInvites/{code}` | `nativeStaging/v1/pairInvites/{code}` |
| Identity locks | Permanent, no updates/deletes; older lockless paired records supported | Both current locks needed for signaling; owner can replace own lock only after prior pair revoked |
| Invitation | Web create/accept contract and 12-character lookup retained | Restricted 12-character alphabet; 30-minute acceptance expiry; explicit second authenticated UID |
| Pair longevity | Existing behavior retained | Accepted pair survives invitation expiry until revocation |
| Revocation | `revoked: true` only; no new audit fields required | Either current member records revokedBy/server revokedAt and clears active pointer atomically |
| Re-pairing | Permanent web locks remain permanent | Fresh code and own lock replacement; old pair and audit retained |
| Room creation | Offer included at creation, pointer published separately | Room and pointer created atomically; opener subsequently writes one immutable offer |
| Answer | Partner writes answer and partnerJoinedAt | Partner writes one answer after offer |
| Room/ICE reads | Membership check; existing expired-room and ICE reads remain allowed | Active, unexpired, matching pointer/roles, unrevoked pair and both locks required |
| ICE writes | Role-bound, active/unexpired current pointer; optional usernameFragment | Role-bound, current authorization; typed and bounded candidate/mid/index |
| SDP / ICE length | SDP <100000, candidate <8192 | SDP 1–256000; candidate 1–8000 |
| Cleanup | Existing host-end/pointer-clear contract | Either member may stop; expired SDP need not be read; stale cleanup cannot clear newer room |
| Web profile photos / daily answers | Own-entry ownership and original question/limits unchanged | No grant to any native photo/question fields |
| Enumeration / deletion | Existing deny clauses retained | Pair/room list and deletion denied; ICE read scoped to authorized room |

Expiry reads in the web baseline are intentionally characterized, not silently
hardened by this change. Previously received client data cannot be retracted by
rules; native media capture is also stopped locally on end/revocation/expiry.

## Verified locally

`npm test` in `native/firebase` loads this exact committed merged artifact by
default. It verifies all hashes and reconstructs the merge before rules loading.
The Firestore demo emulator suite passes **69/69** tests:

- 18 web compatibility tests: nine identical cases before and after insertion,
  including photos, daily answers, old lockless records, offer/answer/ICE,
  revocation, immutable locks, expiry behavior and unauthorized access.
- 27 native security cases: fresh pairing, isolation, expired invitations,
  revoked/re-paired partnerships, stale/foreign locks, duplicate rooms,
  offer/answer roles, ICE direction, expiry, cleanup and namespace boundaries.
- 12 historical-fixture regression cases and 12 merge/integrity checks.

Native and web may use the same UIDs and code without either lock or partnership
being changed by native operations; this is explicitly tested. Browser UI,
Firebase iOS SDK/live pairing and physical-device calls are not established by
these emulator tests. No deployment approval is inferred from test success.

## Deployment gate and rollback

1. Owner explicitly approves this exact additive artifact for staging only.
2. An authorized Firebase operator rechecks the currently published staging
   rules against this baseline immediately before publishing. Stop if changed.
3. Publish the complete `merged.rules`, never the native-only `firestore.rules`,
   to the staging project's default database. This repository does not automate
   this step or hold deploy credentials.
4. Smoke-test existing web pairing/profile/question/call flows, then use two fresh
   native installations. Confirm auth persistence, pair acceptance, actual media,
   End, backgrounding, revocation, fresh re-pairing and expired access.
5. If native access must be rolled back, restore the reviewed baseline only after
   confirming no intervening rules edits. Native access is denied again, web rules
   are preserved, and existing native records remain stored without deletion.

`review.json` retains deploymentApproved=false and liveBaselineVerified=false:
these flags are intentionally not changed by source attestation or emulator runs.
