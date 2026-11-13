# Shared Adventure Book staging activation

The development build defaults to the gated entry. After separate staging approval,
compile the staging app with `REACH_LIVE_ADVENTURE_BOOK` added to inherited Swift
compilation conditions. Live memory creation always requires the quota transaction.
Photo upload and private preview flags stay off. The shared quota rules deny photo
metadata writes. Leave Storage rules untouched.

## Rules and inventory

1. Export the active default-database Firestore rules from `reach-staging-a4745`
   read-only. Record its release ID and hash. Review all overlapping matches and
   preserve web, pairing, authentication and calling rules. Compare the exact
   merged artifacts with that export before any separately approved publication.
2. From this directory run
   `node prepare-shared-adventure-rules.mjs ACTIVE.rules OUTPUT_PREFIX`.
   This produces enforced and frozen rules plus a SHA-256 manifest. Review
   `adventure-book.shared-quota.rules` and re-run the emulator suite on the real
   exported base using synthetic accounts. Both members' locks are checked inside
   rules. Client lock reads remain owner-only.
3. During a separately authorized cutover, publish the reviewed frozen variant
   first. Verify all create paths, including older clients and privileged writers,
   are frozen. Inventory all eligible pairs, including empty books, and count
   existing memory documents. Keep a verified export and record existing counters.
4. Run `node adventure-book-quota-plan.mjs INVENTORY.json`. An authorized
   operator should apply only the reviewed missing counters using create-only
   preconditions and reconcile any drift or over-limit books separately. Keep
   existing memories, IDs, children and counters. Capture an independent inventory
   under the same freeze and run
   `node adventure-book-quota-plan.mjs INVENTORY.json VERIFIED.json`.
   Stop for any discrepancy or unverified book. Reconcile availability of a counter
   for new pairs before expanding the pilot beyond the inventoried accounts.
5. Switch to the exact reviewed enforcement rules only after verification. Verify
   the active hash and staged access. If rollback is needed, restore the reviewed
   frozen variant and retain newly created memories and current counters. Reconcile
   under the freeze before reopening. Avoid restoring a baseline that allows
   uncounted creation.

## Two-iPhone pilot

With approved staging access, install the staging-only live build on both phones.
Confirm each phone opens the same live book. Create a memory from each phone,
cross the eight-card page boundary, edit each own story, and exchange comments.
Check both phones after concurrent writes, reconnect, backgrounding and sign-out.
Verify retries with the same memory/comment ID and stale story edits, a simulated
final quota slot, and denial to an unrelated account. Revoke the pair and separately
change a member lock while the book is open, confirming private content is cleared
on the next successful server recheck or earlier listener denial. Rechecks start
every 10 seconds while open. Inspect the Rules-dependent read cost in staging.
Recheck Existing Memories, pairing and the fullscreen call on both phones.
