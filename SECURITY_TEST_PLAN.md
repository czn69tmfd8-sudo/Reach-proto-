# REACH v1 — Security branch verification (NOT YET DEPLOYED)

## Deployment gate
Do not merge to main or publish these Firestore rules until the Firebase emulator tests below pass. Current production pairings (including Aaron) must be preserved. Never clear Safari site data.

## Existing-pair migration blocker
The new memberLocks/{uid} documents are required for *new* pairing creation/claim. Existing paired accounts do not have them. They must be backfilled using a trusted administrator process that:
1. Inspects existing pairInvites and confirms each UID's one intended partnership.
2. Resolves duplicate/test pairs with explicit consent; revoke obsolete pairs.
3. Creates exactly one lock for each established UID, pointing to the same pair code.
4. Never rewrites hostUid, partnerUid, profilePhotos, or an existing pairing without approval.
5. Verifies both phones still read the correct pair and photos.

Do NOT let clients self-migrate an existing pairing without verifying ownership on the server.

## Emulator tests (not executed)
- Unauthenticated user cannot read/write rooms, pairInvites, memberLocks, or candidates.
- Third authenticated UID cannot get a paired room or list its ICE candidates.
- A member cannot read an unrelated room, even knowing its 6-character code.
- Host and partner can read their own room and candidate collections.
- Only the host can create a room for the correct paired partner.
- Only the partner can write an SDP answer; neither member can rewrite identities or offer.
- Host cannot write partnerCandidates; partner cannot write hostCandidates.
- Unknown room subcollections are denied.
- Expired or inactive rooms reject new candidate writes.
- Revoked pair denies new room reads and candidate reads/writes.
- Two simultaneous pairing attempts by the same UID cannot both commit.
- Claiming an invite must create the member lock in the same transaction.
- Partner UID and pair creation timestamps cannot be modified after claim.
- A member cannot delete their member lock to create a new partnership.
- Profile photos: each member can change only their own JPEG field; other partner's photo remains unchanged.
- Opening, joining, ending a call and reopening it succeed on both iPhones.
- Failed room creation/join resets local state and camera/microphone correctly.

## Deployment coordination
The existing live app and candidate rules use incompatible room schemas. Expect a controlled maintenance window to publish compatible rules and switch the app together, with rollback prepared. Do not publish the candidate rules alone.

## Remaining review
- Firestore emulator compilation and rule behavior
- Existing-pair lock backfill
- Rules resource-read limits
- End-to-end WebRTC and iPhone testing
- Security review of photo writes and pairing access
