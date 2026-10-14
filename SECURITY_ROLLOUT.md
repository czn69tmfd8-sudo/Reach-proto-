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
- Firebase emulator tests not yet run.
- No admin access in this branch to inspect/backfill existing memberLocks.
- Existing account migration and two-phone video tests not done.
- Security audit of Firebase Storage and any other backend services remains to be performed.
