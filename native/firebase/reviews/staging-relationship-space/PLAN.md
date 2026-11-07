# Relationship space pilot review

Target only `reach-staging-a4745`, Firestore `(default)`. This directory is
review material. Publication, pilot activation, and rollback each require
explicit owner approval.

| Artifact | SHA-256 |
| --- | --- |
| Recorded pre-pilot rules and rollback source, `../staging-2026-11-06-hardened/merged.rules` | `7e62b5e95f939d56155ce047634ead33023dfd1e6b35a6e20cb3601c7ddc00b8` |
| Complete additive candidate, `merged.rules` | `ee7ee0ed97e3611aa41eeb7ebf9ba3f0d03fe5754de0171e3e88a3f64b588732` |

The recorded baseline comes from the prior staging review and owner console
evidence. This review did not independently retrieve the active release. The
candidate inserts only the scoped sharing block and its helpers. Removing the
one insertion reproduces every original byte, including all web and native
pairing, room, ICE and consent rules. Build 5 at
`641cc0debc41f3e60517ab1880d8444ab9c5dc94` does not call the new path. The
standalone proposal must never be published on its own.

## Readiness gates

1. Run the complete suite with a locally installed, approved emulator. Confirm
   its executable and runtime are present before invoking the Firebase CLI so
   there is no implicit dependency download. From `native/firebase`, with the
   approved emulator already running, use:

   ```sh
   printf '%s\n' "${FIRESTORE_EMULATOR_HOST:-}" | grep -Eq '^127[.]0[.]0[.]1:[0-9]+$' &&
     REACH_SHARED_MERGED=1 node --test --test-concurrency=1 *.test.mjs
   ```

   This uses the installed Node packages directly and runs existing native/web regressions
   and the new auth, expired-invite, re-pair, revocation, pilot-flag, photo and
   REST concurrency tests. The new suite loads and verifies the exact checked-in
   candidate by default. Use an approved macOS validation runner for native
   compile and tests. Neither gate is satisfied by syntax or hash checks.
2. Retrieve or copy the complete **currently published** rules and record their
   release/ruleset ID. Hash the exact bytes with `shasum -a 256 FILE`. If the
   current source differs from the recorded pre-pilot SHA, stop and rebuild,
   re-review, and retest against that live baseline. Keep the exact pre-pilot
   source and ID available for recovery.
3. In the Firebase console, verify project ID and database. Stage the **complete**
   candidate in the Rules editor, copy it back, and compare its SHA to the
   reviewed candidate. Stop before Publish for explicit owner approval of the
   project, database and candidate checksum.
4. After a separately approved publication, verify the complete published
   readback and release ID. With every pilot flag absent, confirm shared reads
   and writes are denied. Smoke-test an installed Build 5 with synthetic staging
   accounts for existing pairing, explicit consent, offer/answer, ICE and call
   termination. Verify an outsider cannot read rooms or signaling.
5. With separate approval, an administrator sets only
   `nativeStaging/v1/relationshipSpace/{TEST_PAIR_CODE}` to `{enabled: true}`
   for one named synthetic test pair. Both members must already have matching
   locks. Client accounts cannot read or write the flag. Verify two authorized
   installations, a different paired account, an unpaired account, author edits
   and deletes, a 250 KB photo on weak Wi-Fi, concurrent edits, offline/online
   transitions, revocation, and re-pairing. Keep real couple data out of the pilot
   until an administrative retention and deletion process has been approved.

## Validation record

| Check | Result or blocker |
| --- | --- |
| Local Python and offline JavaScript tests | 58 Python and 23 JavaScript tests passed, including exact artifact, tamper and additive-merge checks. |
| Build 5 regression boundary | Original release source guard passed on a reconstructed Build 5 tree. Pairing, auth, signaling, calls, release workflow, and current rules remain unchanged. Installed-device smoke tests are pending. |
| Merged Firestore rule execution | Pending. No approved local emulator was running or installed. The exact-candidate suite includes revocation, cross-couple isolation, expired invitations, accepted pairs after the invite deadline, unauthorized edits/deletes, concurrent writes, photo size limits and legacy native/web regressions. |
| Native compilation and XCTest | Pending. Local Xcode and Swift were unavailable. The existing GitHub Actions native CI installs XcodeGen and resolves Swift packages. The Codemagic validation-only workflow is pinned to an earlier app fingerprint and also needs dependencies. Use a preprovisioned macOS runner or explicitly approve required downloads and an exact-source validation-only run. |
| Together and Us review | Source inspection verified separate visibility labels, initial and retry loading indicators, bounded photo previews, and blocked shared mutations while offline. Simulator/device interaction, accessibility, reconnect behavior, and photo timing remain unverified. |
| Live Firestore release | Pending authenticated readback of the complete staging rules and release ID. No live staging changes were made. |
| Two-device pilot | Pending validated native build, reviewed staging publication, and separate approval for one synthetic test pair. No real couple data is needed. |

## Rollback

For a single pilot pair, obtain authorization to set its flag to
`{enabled: false}` or remove the flag document. This blocks new shared requests.
It does not delete any entry or photo. If authorization or legacy behavior fails
more broadly, restore the exact recorded pre-pilot complete source as a **new**
Firestore rules release for the same database after explicit rollback approval.
Confirm the live release is still the candidate first. If another release
intervened, stop and review before overwriting it. Verify the restored checksum,
shared denial, and Build 5 smoke tests. After disabling sharing, account for
already delivered responses and an open app's short foreground cache. Do not
delete any documents as part of rules rollback.

## Data and performance limits

- A photo is capped at 250,000 raw bytes. The 6,000-byte caption and 120-byte
  title leave the document well below Firestore's 1 MiB limit even with other
  fields and overhead. Base64 adds about one third on the REST wire. Photo
  and fields are written atomically. Rules enforce type and size, while the
  client re-encodes photos and bounds thumbnail dimensions.
- A full 12-item page can still contain about 3 MB of raw photos, roughly
  4 MB before HTTP compression on the wire. Unchanged polls project only dates
  and metadata. Changed pages can perform two reads and reload all photos. This
  cuts payload size for unchanged pages, not read billing. Measure latency,
  transfer and read volume before expanding the pilot.
- Server revocation, a changed lock or a disabled flag denies subsequent
  operations. A previously delivered snapshot can remain visible for up to 45
  seconds during a transient foreground outage. The client clears it on a
  confirmed denial, observed identity change, backgrounding or expiration.
  Recipients can keep copies or screenshots.
- Mutations have document-version preconditions and no persistent offline
  queue. A write sent just before navigation or disconnect may have committed.
  On an uncertain response, refresh before recreating the entry, or retry the
  same draft and UUID. Closing the editor or losing access can discard an
  unsaved draft. After revocation, clients also lose delete access to old
  records. Administrative cleanup must be planned and separately approved.
