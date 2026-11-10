# Adventure Book — secure synchronization plan (not deployed)

## Current boundary
The SwiftUI book is a visual sample. The `AdventureMemory` contract and tests are offline-only. No Firebase rules, storage bucket, authentication, existing pairing, production data, or calling behavior has been changed.

## Proposed persistence
- Firestore: `adventureBooks/{pairCode}/memories/{memoryID}` for title, date, page order, creation metadata. Separate child documents for `stories/{authorUID}` and `comments/{commentID}` so each contributor's ownership is enforceable at the document level.
- Firebase Storage: `adventureBook/{pairCode}/{memoryID}/{photoID}` for original photos. Store metadata and ordering separately in Firestore. Verify upload content type, byte limit, ownership and size on the server; never trust a client-provided URL.
- Never auto-publish existing private scrapbook entries. Import requires explicit per-entry consent and preview.
- Use stable immutable UID for author identity; display names are presentation only.

## Required authorization before any deployment
- Every read and write must check authenticated membership of the **current** non-revoked pair, including both member locks. Do not authorize from pairCode alone.
- Story document ID must equal `request.auth.uid`; only its author can create/update/delete it. Clients cannot write the other person's story.
- Comment creation binds `authorUID` to authenticated UID; deletion and editing require an explicit, reviewed ownership policy.
- Memory deletion and photo deletion need a separately agreed policy. Avoid dangling storage objects and do not delete a partner's authored content silently.
- Pair revocation must deny access immediately in Firestore **and** Storage; test stale sessions, expired pairing, malicious paths and cross-pair access.
- Limit payload sizes and document counts; add pagination and abuse protections. Treat photo EXIF/geolocation carefully; strip metadata on export or upload by default.
- Keep original-resolution media for future printing with storage quota, download/export and deletion policies.
- Never put direct download tokens into broadly readable Firestore fields.

## Testing gates
1. Pure Swift model tests for two-author edits, invalid ownership, comment ordering, duplicate IDs, serialization and photo paths.
2. Firebase emulator tests for both paired members, outsiders, revoked pair, stale member locks, write spoofing, cross-pair reads, oversized uploads and concurrent edits.
3. Real two-iPhone staging test: each partner uploads one photo and their own story, sees updates, comments, then tests offline/reconnect.
4. Confirm existing call, pairing and revocation regression tests still pass.
5. Explicit approval required before changing staging rules, publishing to TestFlight, or touching production.

## UI evolution
- Keep swipe paging and reduced-motion fallback.
- Replace placeholder with a real page data source after authorization is verified.
- Realistic page curl is a separate animation milestone, not implemented by the current TabView.
- Printable page composition is a future feature; do not assume a screen screenshot is print-ready.
