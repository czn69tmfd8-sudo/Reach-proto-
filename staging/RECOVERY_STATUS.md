# Staging recovery implementation status

- `recovery-core.js`: browser-only synthetic preview (11 checks).
- `recovery-transaction.mjs`: server-side atomic Firestore transaction core, **not deployed**.
- `RECOVERY_BACKEND_SPEC.md`: security design and deployment gates.

## Critical limitations
The transaction core assumes a trusted server already authenticated both parties and wrote a valid challenge. **Do not expose it directly to browser callers.** Approval fields in Firestore are not inherently trustworthy unless only a privileged server can write them. Authentication enrollment, approval endpoints, App Check, abuse controls, challenge creation, production backup, Firestore emulator integration tests, and deployment are still outstanding.

## Existing account constraint
The current production pairing uses anonymous Firebase UIDs. Without previously enrolled recoverable credentials, the backend cannot reliably prove that a replacement UID is the same human as an earlier anonymous UID. Never recover from knowledge of a pair code alone.

## Next engineering tasks
1. Add callable server endpoint to enroll verifiable identity without replacing current anonymous UID.
2. Implement server-generated challenge and independently reauthenticated approvals.
3. Add emulator tests for replay, race, rollback, old UID exclusion, photo retention and audit.
4. Only then consider a staged rollout, with explicit user approval.
