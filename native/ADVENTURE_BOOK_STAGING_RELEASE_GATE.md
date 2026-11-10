# Adventure Book staging release gate — review only (NOT deployed)

## Existing protected resources
- Firebase staging project: `reach-staging-a4745`; default Firestore database and its associated Storage bucket.
- Existing native pairing, member locks, room signaling, WebRTC, hand interaction, production `reach-prototype-d70ef`, and user records MUST remain unchanged.
- Keep existing `nativeStaging/v1/pairInvites/{code}` and `nativeStaging/v1/memberLocks/{uid}` rules and data intact.

## Exact proposed additions
- Firestore: additive match `/adventureBooks/{code}/memories/{memoryID}` with `stories/{authorUID}`, `comments/{commentID}`, `photos/{photoID}`. Candidate text: `native/firebase/adventure-book.proposed.rules`. Merge into currently deployed staging rules; **never** deploy the proposed fragment as a standalone replacement.
- Storage: additive path `/adventureBook/{code}/{memoryID}/{photoID}` in the staging bucket. Candidate: `native/firebase/adventure-book.storage.proposed.rules`. Merge with existing Storage rules and verify unrelated existing paths remain unaffected.
- Clients: `FirestoreAdventureBookRepository`, `FirestoreAdventureStoryTransport`, `FirestoreAdventurePhotoTransport` and `ReachAdventureBookLive` in the feature branch; do not distribute before native validation.

## Security requirements before deployment
1. Cross-couple/anonymous denial, partner-only story ownership, comments, photo metadata and object reads; revocation, expired access and both member locks.
2. Transactional stale-version rejection, with the winning text preserved.
3. Storage first upload succeeds; replacement and unauthorized upload/read fail; 15 MiB JPEG size/content-type/owner metadata enforced.
4. Verify **existing** rules by merging them with candidate rules in emulator; check all legacy pairing/calling/hand tests.
5. Evaluate download-token behavior and cached bytes: previously issued Firebase download URLs and locally cached files cannot be guaranteed instantly revoked. The native implementation must never issue permanent bearer URLs, and should discard image memory on revocation.
6. Current proposed rules intentionally **deny photo object and metadata deletion**. A separate authorized deletion policy, with owner/partner consent, tombstones, object cleanup and emulator tests, must be approved before enabling deletion. Revocation itself must never delete data.
7. Verify Firebase Storage SDK API calls and transaction closure compile on an actual macOS/iOS simulator before distributing.

## Rollback
- Before any staging deployment, export the current Firestore and Storage rulesets, identifiers and checksums.
- Apply only the reviewed additive rulesets after explicit owner approval; retain a tested revert to the exact prior ruleset.
- Do not delete Adventure Book documents/objects during rollback. Reverting access rules can make content temporarily unavailable without destroying it.
- No changes to production, pairing data, existing client releases or TestFlight without separate explicit approval.

## Verification sequence after approval
1. Stage merged rules only to the staging project, then compare deployed rules hashes to reviewed files.
2. Two staging-authenticated paired iPhones: create memory on A, confirm on B; independently write two stories; comment from both; photo upload on A and private read on B.
3. Edit stale story from second session and confirm conflict, not overwrite.
4. Revoke staging access under a controlled test account, confirm both live listener shutdown and server read/write denial, and verify data remains in Firestore/Storage.
5. Exercise interrupted upload, retry with matching SHA-256, mismatch denial and offline reconnect. Never silently overwrite existing objects.
6. Verify existing calling, audio, hand interaction, Together navigation and old scrapbook remain intact.

## Current validation and unresolved gates (2026-11-09)
- Codemagic isolated unsigned simulator build #8 at b21d033 completed successfully (4m 27s); this is not a signed physical-device build or evidence of two-device Firebase synchronization.
- Existing historical baseline, portable Swift, and Firebase security emulator suites passed on b21d033 (69 Python, 181 portable Swift, 14 Firebase security). Re-run after any change to rules or native code.
- Live UI has brown vintage-style cover, parchment pages, page navigation, partner stories, comments and authenticated photo picker/display. Textured leather, physical page-curl animation and full accessibility/visual polish are not demonstrated.
- A durable photo recovery **journal** is implemented. Original image bytes are not persistently stored, so a killed app may require selecting the same photo again before cryptographic recovery. Client-side delete remains prohibited. No privileged orphan cleanup exists.
- Listener callbacks ignore cached snapshots; server reads and pairing/member-lock revalidation precede display. Physical-device offline/reconnect, race and revocation behavior remain unverified.
- Memory queries are capped at 50; child story/comment/photo collections are bounded. Pagination and scaling are not complete.
- No confirmed current live staging Firestore/Storage rule exports or independent diff. The proposed Storage file is a complete ruleset, not an additive patch: **never deploy it directly over live staging rules**. Compare against current live rules and retain unrelated permissions.
- Existing simple limit-only queries do not demonstrate a need for new composite indexes. Confirm against actual staging errors before adding any.
- Authentication, Firebase project ID, Storage bucket, app signing, privacy permissions, staging plist and device entitlements must be confirmed before any physical-device build.
- Do not use an unsigned simulator artifact on an iPhone; a signed archive/export and private distribution require separate explicit approval.

## Staging preparation commands (safe, do not deploy)
```sh
git fetch origin feature/adventure-book-foundation
git checkout feature/adventure-book-foundation
git rev-parse HEAD
python3 -m unittest discover -s native/scripts -p 'test_*.py'
python3 native/scripts/run-portable-tests.py
cd native/firebase
npm ci
node prepare-adventure-rules.mjs
```
Use `.github/workflows/adventure-book-historical-baseline.yml` for the exact isolated Firestore+Storage emulator execution. Its generated rules use a repository review baseline, **not necessarily current live staging**.

## Staging-only deployment command (APPROVAL REQUIRED — DO NOT EXECUTE)
After fetching and backing up the actual active staging rules and reviewing **both additive merges**, prepare a temporary Firebase config whose Firestore and Storage rule paths point exclusively to those reviewed merged files. Validate that the CLI target is the staging project and that no existing rules disappear. Only then, with explicit owner approval:
```sh
firebase deploy --project reach-staging-a4745 --only firestore:rules,storage --config ./adventure-staging-approved.firebase.json
```
Check CLI compatibility and exact resources before execution. Preserve immutable copies/checksums of both predeployment rule releases and approved merged files. Read back deployed rules, compare hashes and rerun pairing/calling/security smoke tests. If rollback is approved, restore the exact backed-up staging rules using a separate rollback config and explicit staging project target; never delete user data.

## Two-iPhone test and distribution boundary
- First obtain authorization for staging rules and signed internal device distribution (distinct approvals).
- Keep `com.reachprototype.app` and the verified staging Firebase configuration consistent with existing working native pairing; never point this feature at production.
- Install the signed staging build on device A, verify existing calling/hand interactions; then on paired device B. Confirm shared memories, independent story edits, comments, authenticated photo bytes, interrupted upload recovery, offline reconnect and stale edit conflict.
- Under controlled test identities, confirm cross-couple denial, revocation and member-lock enforcement; clear visible private content and verify stored objects remain untouched.
- Do not upload to TestFlight or distribute without separate approval.

## Live-rule retrieval blocked — exact read-only handoff
This development environment has a GitHub connection but no authenticated Firebase Rules API/CLI session. The historical `native/firebase/fixtures/deployed-staging-2026-11-05.rules` is **not** proof of the currently active Firestore rules. No live Storage rules export is present. Do not substitute either proposed rules file for the actual deployed rules.

**iPhone read-only steps:** Sign in to [Firebase Console](https://console.firebase.google.com/) using the account with Viewer access to `reach-staging-a4745`. Select that exact project (not `reach-prototype-d70ef`). Open **Build → Firestore Database → Rules** and copy the full currently published rules (not a draft). Then open **Build → Storage → Rules** and copy the full published rules. If the Rules tabs or published source cannot be viewed, ask the project owner for Firebase project Viewer / Firebase Rules Viewer access sufficient to read active rules releases; do **not** request Editor/Owner or deployment privileges. Share both exports privately for review; avoid pasting any secrets or service-account credentials. Also record the exact Storage bucket name shown under Storage → Files, Firestore database ID, and any active composite indexes from Firestore Database → Indexes.

**Alternative read-only API:** An authorized operator may use `firebase rules:list --project reach-staging-a4745` if supported by their installed CLI, or the Firebase Rules REST API `projects.rulesets.list` and `projects.releases.get` / `projects.rulesets.get` with appropriate read permissions. Never assume the most recently created ruleset is active: resolve the active release. Do not run `firebase deploy` or `firebase use` to change the target.

**Offline review after both exports arrive:** From `native/firebase` run
```sh
node merge-live-adventure-rules.mjs /path/to/active-firestore.rules /path/to/active-storage.rules /path/to/private-review/merged
node --test merge-live-adventure-rules.test.mjs
```
The merger writes a review-only Firestore candidate, Storage candidate, and SHA-256 manifest. Its syntactic guard is **not a security proof**: an independent diff must verify all existing match blocks, overlapping wildcard rules, helper names, and denies. Reconfigure Firebase emulator tests to use **those exact merged candidates**, including legacy regression tests, before requesting deployment approval. Never commit private live-rule exports to a public branch without an explicit disclosure review.

**Decision gate:** Until the current active Firestore and Storage rules are available and independently diffed, the full merged candidate, exact deployment diff, and rollback release IDs remain **blocked**. No deployment approval is being requested.
