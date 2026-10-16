# REACH v1 — Controlled rollout and rollback

**Status: NOT APPROVED FOR PRODUCTION.** This branch is a candidate. Never paste its rules into the live Firebase console before validation.

## Preconditions
- Preserve the current main branch and the currently published Firestore rules as rollback references.
- Identify both existing anonymous Firebase UIDs and the *same* Aaron pair code using authenticated Firebase admin inspection; do not paste UID values or pair codes into public GitHub files.
- Inspect all old test pairs and confirm which to revoke; preserve the real pair and its profilePhotos.
- Validate the security rules with Firebase Emulator Suite and two authorized plus one unauthorized auth identities.
- Test fresh new-pair creation and claim with memberLocks transactions.
- Check whether existing pair requires lock migration. If so, create both memberLocks through trusted administrator access only after verifying ownership.
- Check syntax and functionality of the app JavaScript before merging.
- Verify room create, partner answer, candidate exchange, room end, reconnect, photo syncing and revocation.
- Do not clear Safari website data on either phone.

## Verified live baseline — October 16, 2026
- Both iPhones successfully authenticated as their existing anonymous Firebase identities.
- Both phones read the same existing pair document and confirmed distinct partner UIDs, both JPEG profile photos, no revocation, and a clear active-room pointer.
- The current published Firestore rules correctly deny client reads of memberLocks; neither phone's diagnostic can independently validate the lock until rules change.
- The couple completed a live two-phone REACH video call, confirming two-way audio, video, and a stable connection.
- Firebase security workflow for candidate branch commit ba04684 completed successfully, including migration-style tests with two locks and both photos.
- **Do not interpret this as a candidate-app call test.** The working call was on the unchanged main app with unchanged production rules.

## Mandatory release gate (remaining)
1. **Console migration completed (visual verification):** October 16 screenshots show the selected `/memberLocks` collection listing BOTH `EflcyNjVHsYACPi5jzOKzH2Cvsw2` and `MKkWabfX7OVPoEhsM2vnCiiRdMm1` in the same middle-column document list; each had `pairCode` `VR5VUZFHPWMQ` in prior field screenshots. This is stronger evidence than the earlier separate-collection screenshots. The root still shows another visually similar `memberLocks` label, possibly whitespace or Unicode; do not delete it or assume its identity. **Before production cutover:** confirm both canonical paths via authorized read-only access or both phones after rules deployment. No Firebase Admin connector is currently available.
2. Validate production-specific room signaling and profile photo updates against candidate rules in the emulator, including the exact WebRTC candidate shapes emitted by Safari.
3. Confirm a reversible, time-boxed coordinated cutover plan. The complete published Firestore rules have NOT been recovered verbatim in the current review (mobile Safari cannot reliably select all); the console's published version history is an available fallback but an exported copy is preferable. Do not represent a screenshot of the first lines as a full backup.
4. Publish new app HTML and new rules only as an explicitly approved coordinated cutover. Existing live sessions must be ended first. A partial rollout can interrupt calling.
5. Verify both phones and run a two-way call, then verify unauthorized third-party room access is denied. Roll back both components if the baseline regresses.

## Migration
The candidate rules permit an existing non-revoked pair to keep reading its rooms/photos without memberLocks; the lock migration is for future single-partner enforcement and must be done carefully. An account with an old pair but no lock could otherwise create another pair, so do not call the one-partner guarantee complete until legacy identities are backfilled.

## Cutover
1. Agree on a short maintenance window with both people, since room schemas are incompatible.
2. Save the live Firestore rules and main commit identifier.
3. Ensure no active call is underway.
4. Publish verified rules and release matching HTML in a coordinated sequence; expect a temporary interruption. Do not claim zero downtime.
5. On each iPhone reload normally (never clear browser data), check pairing/photos, then place a short video call.
6. Test third-device room get/list and candidate access; these must fail.
7. Revoke an obsolete test pair only after the real pair is confirmed.
8. Confirm revoked accounts can no longer read the pair or its rooms.

## Rollback
If either phone loses its real pairing, photos, or video connection, stop testing. Restore the saved live HTML and matching original Firestore rules. Be aware that new-schema room records and memberLocks created during the cutover may not be compatible with the old app. Rollback does not erase data or restore lost anonymous authentication identities.

## Known blockers
- Both phone-specific checks passed against current production pairing data; candidate memberLock reads remain untested on-device.
- The GitHub Firebase emulator workflow passed on candidate commit ba04684; real-device validation of candidate rules is still pending.
- No Firebase Admin access is connected for independent inspection of production documents. Screenshots indicate two existing memberLocks with the same pairCode, but do not replace read-only checks on both phones.
- Coordinated two-phone video tests on the new app and rules have not been done.
- Security audit of Firebase Storage and any other backend services remains to be performed.

## October 2026: read-only diagnosis before considering a fresh pairing

The live REACH screen showing a named partner and cached photos is not proof that the selected Firestore pair document is currently accessible. The mobile Firebase console also does not reliably show all collection documents in a narrow layout.

The development-only **Connection health check** reports the current anonymous auth UID, locally selected pair code, own permanent lock's pair code, and whether the selected pair record is readable and contains this UID. It never creates or changes data. Do not publish the diagnostic to production until the security test suite passes and the team agrees to deploy.

**Do not implement a client-side "reset partnership" button that deletes or rewrites memberLocks.** Immutable locks are the one-partner security boundary; weakening them to let a client pick any new partner would undo that protection. A fresh pairing using the *same anonymous UIDs* requires a privileged, authenticated administrator migration with verified consent of both members and an auditable plan for old-pair revocation. This project has no connected Firebase Admin write capability. If admin access is unavailable, use a supervised, controlled migration, not a broad Firestore rule that permits self-reset.

Before any reset, capture the two phones' diagnostic outputs, verify the existing pair's hostUid/partnerUid and both locks with trusted Firebase admin access, and check whether the existing pairing can simply be repaired. Preserve both browser identities and photos until after a successful two-phone call. Never instruct users to clear Safari data.

## October 16, 2026 follow-up review (GitHub only; no production writes)
- Inspected candidate Firestore rules and candidate `index.html` together. The candidate requires `rooms` documents with `partnerUid`, `pairCode`, `createdAt`, `expiresAt`, `active`, and `offer`; the current live version uses a different room schema. **Never deploy only one half.**
- Candidate code reads `/memberLocks/{currentUser.uid}` to restore the intended pairing and rejects opening/joining when the lock is absent or mismatched. Both migrated UID documents now appear together in the canonical-looking collection in the user's latest screenshot.
- Candidate room opening requires pair `activeRoom == null` AND `openedBy == null` before setting a new pointer. User verified `activeRoom == null`, but `openedBy` has NOT been verified; a stale non-null `openedBy` would block calls under candidate rules. Check without changing the record before cutover.
- The candidate uses `RTCIceCandidate.toJSON()` for ICE writes. The rule accepts `candidate`, `sdpMid`, `sdpMLineIndex`, `usernameFragment` only. Validate actual iPhone Safari output and optional/null values in emulator before cutover.
- No production rules, pair records, photos, live HTML, or phone browser state were modified by this review. The working live call remains the baseline.
