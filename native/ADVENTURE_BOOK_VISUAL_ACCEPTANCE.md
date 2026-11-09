# Adventure Book visual acceptance criteria

The reference mockup is the design target, not an existing implementation.

## Cover
- Dark brown leather-like book cover with a stitched or embossed border.
- Serif title “Our Adventure Book” and subtle heart detail.
- Warm, romantic visual style consistent with the existing REACH sunset background.
- No placeholder text suggesting a real couple's private photos are already synchronized.

## Inside pages
- Warm cream/parchment page surface, not a generic white card.
- Photo displayed prominently with scrapbook-style framing and optional handwritten-looking caption.
- Both partners' first-person stories are equally prominent; neither is relegated to comments.
- Long stories must be readable with Dynamic Type and VoiceOver; on compact iPhones stack stories rather than compressing into tiny columns.
- Comments are separate from the two stories.
- Swipe navigation plus explicit Previous/Next controls; respect Reduce Motion.
- Eventually support true page curl, but keep it a separate enhancement from data correctness.
- Display loading, offline, permission-revoked and empty-book states clearly.

## Shared data and privacy
- The same book appears to both currently paired partners.
- Edits to one story cannot overwrite the other author's story.
- Original photos retained for future printing; provide user-visible storage and export policy.
- Never auto-import existing private entries.
- Never imply a preview's local Save action is durable or synchronized.

## Acceptance before TestFlight
1. Swift model tests and native simulator compilation pass.
2. Firestore and Storage emulator tests prove pair isolation and revocation.
3. Two real paired iPhones create, view and edit the same memory.
4. Existing calling and pairing regression tests pass.
5. Explicit approval obtained for staging configuration changes and TestFlight upload.
