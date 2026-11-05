# Native staging security rules

`npm ci && npm test` runs the actual Firestore rules engine against the local
`demo-reach-native` emulator. No Firebase login, project credentials or live writes
are used. The root production hosting configuration is deliberately untouched.

These rules are an explicit staging-only ruleset for pairInvites, memberLocks,
rooms and directional candidate subcollections. They deny all other collections.
Review against the currently deployed staging rules before publishing: the
repository does not contain an authenticated export of those rules.

To deploy after that review, from this directory only:

```
npx firebase deploy --only firestore:rules --project reach-staging-a4745 --config firebase.json
```

Never run this against production or omit the project argument. Enable Firebase
Authentication's Anonymous provider in reach-staging-a4745 if it is not enabled.

Use two fresh authenticated installations. A creates a code in Staging; B accepts
it; A refreshes status. A selects Open hand; B selects Take partner's open hand.
Both explicitly grant camera/microphone access. Confirm actual sound and moving
remote video in both directions. End, reopen, revoke, and verify the other device
stops. Backgrounding or leaving the Staging view stops local media. A revoked
membership lock is intentionally permanent; client-side reset is forbidden.

Ended/revoked/expired rooms reject further ICE reads/writes. Candidate documents
remain inaccessible under ended rooms; physical deletion/retention needs a trusted
server janitor, not client permission to erase another user's signaling history.
