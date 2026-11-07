# Native lookup hardening — local review, publication not approved

Target for any separately approved future publication: `reach-staging-a4745`,
`(default)` Firestore database only. No Firebase changes were made by this work.

## Published comparison source

The owner published the previous artifact and supplied its complete source and a
Rules history screenshot showing **Today · 8:28 AM** on November 6, 2026.
The source is archived in `../staging-2026-11-06-fresh/merged.rules`, SHA-256
`d23ac0d8a31496a10ac0fff6e3d439daf3951d3246ec74154d6e956ef0f7e70a`.
This is owner-attested publication evidence, not a fresh authenticated API read.
Do not infer a console timezone from the screenshot. Recheck the live project,
database, release and full source before any future publication; stop if changed.

## Exact artifacts

| Artifact | Lines | Bytes | SHA-256 |
| --- | ---: | ---: | --- |
| Previously published merged rules | 929 | 29813 | `d23ac0d8a31496a10ac0fff6e3d439daf3951d3246ec74154d6e956ef0f7e70a` |
| Proposed complete merged.rules | 990 | 33591 | `7e62b5e95f939d56155ce047634ead33023dfd1e6b35a6e20cb3601c7ddc00b8` |
| Unchanged web baseline | 833 | 21984 | `437d87ced527f053b807ba7744fc61bb74ed3a3f0e2c93e2aa61a9ca386ef86e` |

Removing each artifact's recorded native insertion reconstructs the **same web
baseline byte-for-byte**, including whitespace. `published-vs-hardened.patch`
compares the complete old and new sources. Every change is inside the native
insertion. All archived review bundles remain unchanged. The two-space blank
line at the insertion boundary is inherited and deliberately retained.

The default emulator tests load this exact new committed review, reconstruct it
from the web baseline and current native-only candidate, and check its hashes.
Web compatibility now uses the exact fresh-format web baseline for both sides.
Do not deploy `firestore.rules`: it is the native-only emulator candidate.

## Behavior changes and preserved controls

- Authenticate and check room existence before reading room data. ICE get/list
  and create use the same guarded parent-room helper.
- Validate the 12-character native invite code before constructing a pair path.
  Validate UID/room document IDs (string, single nonempty segment, not dot or
  reserved IDs, at most 1500 UTF-8 bytes) before dependent lock/room paths.
- Guard pair/lock existence before get(), and post-transaction existence with
  existsAfter() before getAfter(). Validate room field types and pair identities;
  missing fields yield denial instead of invalid dependent paths.
- Validate SDP maps before accessing their fields. Reject missing room-state
  fields when opening a room. Keep paired-invite expiry independent of room
  expiry: an accepted partnership remains usable until revocation.
- Dispatch invite updates by changed fields; use one shared current-pair check
  for offer/answer updates. This avoids expression-limit failures on denied
  requests without removing authorization checks.
- Preserve two-member identity/role checks, both native locks, explicit acceptance,
  caller offer/partner answer, immutable signaling, active room pointer/opener,
  room active/expiration checks, candidate direction/schema limits, irrevocable
  audited revocation, authorized cleanup and own-lock re-pairing after revocation.
  Existing web permanent-lock, pairing, profile, question, room and ICE clauses
  are unchanged. No data migration, deletion or application-code change occurs.

## Validation

`npm --prefix native/firebase test`: **100/100 passed**, no failures, skips or
cancellations. All original 69 cases remain, plus 31 lookup regressions. See
`validation.json` for counts, versions and exact artifact hash. Tests use only
local demo projects, including admin-seeded malformed fixtures in the emulator.

New cases cover the exact unauthenticated Playground path; missing rooms and
orphan ICE; empty, missing, null, wrong-type or path-like pairCode; malformed and
oversized identities; malformed room status/expiry; missing pair/locks; stale
locks/pointers; revoked pairs; expired/ended rooms; authorized members/outsiders;
both ICE directions and get/list/create; malformed post-state paths and SDP.
Denied requests must return permission-denied without concrete null/undefined,
invalid-path/service-call or expression-limit diagnostics. The emulator sometimes
includes a generic `evaluation error ... false` label even when a guard denies;
that label alone is not treated as proof of a concrete runtime error.

As a negative control, the new missing-room regression was run unchanged against
the previous published source in an isolated temporary harness. It failed as
expected with `Null value error` on the authenticated read. The hardened version
passes. The precise Playground UI `invalid_argument` message was not reproduced
with the old rules, so eliminating that UI message is not claimed or live-tested.

## Future manual publication and rollback

1. Obtain separate explicit approval for this exact **new** checksum. Earlier
   approval for the 929-line artifact does not authorize publishing this version.
2. In the staging project and default database, verify the latest published source
   still matches the 929-line d23ac0d8 artifact, and check its release history.
   Stop on any intervening differences.
3. Paste the complete 990-line `merged.rules` candidate, copy the entire editor
   content back for exact checksum verification, and stop before Publish until
   the owner explicitly approves publication.
4. After any future publication, verify the release and full source readback;
   repeat read-only simulations and authorized staging checks separately.

Rollback for this proposed update is the **previous complete merged rules** at
`../staging-2026-11-06-fresh/merged.rules` (929 lines, d23ac0d8 SHA above), not the
web-only baseline. Confirm no intervening edits, obtain explicit approval, paste
that complete source and verify it before publishing. Rollback restores the
previous native policy without deleting any documents. No rollback is executed
or authorized by this document. Authentication, production, web data, billing and
native application code remain outside this change.
