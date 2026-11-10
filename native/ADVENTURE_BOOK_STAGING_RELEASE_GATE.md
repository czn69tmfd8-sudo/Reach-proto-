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

## Known blockers as of this review
- Native GitHub Actions jobs pending before any job starts. Portable Ubuntu and Firestore emulator tests have run, so this is not evidence of a Swift compilation failure.
- Codemagic is configured for manual unsigned simulator validation; owner may need to select the feature branch and run it. Do not enable paid resources or uploads.
- Native photo selection currently accepts only JPEG bytes; other Photos formats require explicit conversion before support.
- Upload state is currently in-memory; durable recovery journal, cleanup and deletion are not yet implemented.
