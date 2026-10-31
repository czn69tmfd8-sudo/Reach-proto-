# Native Firebase adapter plan

The native app consumes Firebase only through the protocols in `FirebaseProtocols.swift`.

## Environment rule

Native development targets **reach-staging-a4745** first.

The production project **reach-prototype-d70ef** remains write-locked by
`ReachEnvironmentGuard` until native identity migration and two-device
staging tests have passed.

## SDK boundary

When Firebase Apple SDK is added, keep SDK-specific types inside adapters:

- `FirebaseAuthProvider` -> `ReachAuthenticationProvider`
- `FirestorePairStore` -> `ReachPairStore`
- `FirestoreRoomStore` -> `ReachRoomStore`

Domain models, views, coordinators, and tests must not import Firebase.

## Pair reads

1. Authenticate the installation.
2. Read `memberLocks/{uid}`.
3. Resolve its `pairCode`.
4. Read `pairInvites/{pairCode}`.
5. Verify the authenticated UID is host or partner.
6. Reject revoked/incomplete pairs.
7. Start a snapshot listener on the pair document.

## Session creation

Creating a hand-open session must be atomic:

1. Re-read the pair in a Firestore transaction.
2. Verify it is usable and the caller is a member.
3. Reject an active room opened by the other partner.
4. Create the room record.
5. Set pair `activeRoom` and `openedBy` to that exact room/caller.
6. Return the domain `ReachSession`.

This avoids two phones simultaneously overwriting each other's open hand.

## Session cleanup

Ending is conditional/idempotent:

- Delete/close the room as appropriate.
- Clear pair `activeRoom` and `openedBy` only if `activeRoom` still
  equals the session being ended.

An old cleanup must never clear a newer session.

## Signaling

Room signaling stays behind the room/media transport boundary:

- offer
- answer
- hostCandidates
- partnerCandidates

Firestore signaling completion is not treated as media connection success.
Only the media transport may report the call as connected.

## Secrets/configuration

Do not commit:

- GoogleService-Info.plist
- signing certificates
- provisioning profiles
- App Store Connect keys

The staging plist is injected by the build environment once the iOS Firebase
app is registered.
