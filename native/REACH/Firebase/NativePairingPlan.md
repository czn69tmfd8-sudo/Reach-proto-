# Native Firebase migration contract

The native app must preserve the security meaning of the current production data before it ever writes to production.

## Existing production truth
- Authentication currently gives each web installation a Firebase anonymous UID.
- memberLocks/{uid}.pairCode is the authoritative permanent partnership selection.
- pairInvites/{pairCode} contains hostUid, partnerUid, revoked, activeRoom and openedBy.
- rooms/{roomCode} is the signaling session.
- Candidate subcollections are hostCandidates and partnerCandidates.
- Ending a paired session clears activeRoom/openedBy only when the pair still points at that room.

## Native rules
1. Do not infer authorization from a locally remembered pair code.
2. Resolve the authenticated UID's memberLock first.
3. Fetch that pair record and verify the UID is hostUid or partnerUid.
4. Reject revoked or incomplete pairs.
5. Only then expose the partnership to the UI.
6. A partner may take a hand only when activeRoom exists and openedBy is the other UID.
7. Ending a session must be idempotent.
8. Native identity migration must be designed explicitly: a new native anonymous UID will NOT automatically equal the existing Safari UID.

## Critical migration issue
The web app's device identity is anonymous-auth based. Installing native REACH creates a different Firebase auth installation/UID unless we intentionally migrate identity.

Therefore native REACH must not simply point at production Firebase and expect the existing Byron/Aaron pair to work.

Before live native pairing is enabled we will choose and test a migration path. Until then native development uses adapters/mocks and must not mutate production.
