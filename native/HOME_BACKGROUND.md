# Native REACH home design

## Web reference and exact photograph

The reference is `index.html`: scenic background (around line 420), paired circular
portraits/heart and two hand controls (around line 1698), and the pink/blue scenic
dock styles. The web files are unchanged.

The default native photograph is the exact web asset `staging/Reach back.png`,
introduced in `3af9dd4`. Available repository history contains no larger original.

- 864 × 1536 RGB PNG, 3,274,042 bytes.
- SHA-256: `b1b72b03ca4f7d331daec329edf39c67136e7ae09daa180ac11b62a56a3f8efc`.
- Native copy: `REACH/Assets.xcassets/OriginalSunset.imageset/ReachSunset.png`.

The files are byte-for-byte identical. No screenshot extraction, resizing,
re-encoding or substitute image was used. Preserve Byron and Aaron’s sentimental
photograph. Screen aspect-fill cropping and a separate readability overlay leave
the original asset intact. Reset always restores this bundled default.

## Presentation and customization

- Reach: original photograph, purple/pink glass panels, two circular portraits,
  prominent gradient heart, pink “My hand is open” and blue “Take their hand”.
- The heart gently pulses for a recently verified pairing. It does not claim the
  partner is online or that a call is live. Reduce Motion/background pauses it.
- Together: an optional local personal message and a clear future shared-space
  boundary. The development demo is behind an explicitly labelled navigation link.
- Us: local display names, both local profile pictures, optional message and
  background selection. No personal names or religious text are seeded.

Photo selection uses the system PhotosPicker, rather than whole-library access.
Selected photos are downsampled on import, written atomically with complete file
protection to Application Support and excluded from backups. They are not uploaded
or synced. Clear/remove deletes the selected local file. Labels explicitly state
that partner imagery is local, not a verified image supplied by the remote member.
Names and messages persist as local appearance preferences. Default photograph
bytes are never passed through this import path.

`ReachHomeBackgroundSource` and `ReachAppearanceStore` are presentation boundaries,
independent of pairing locks and Firebase authorization. Future member-controlled
profile sharing requires its own consent, storage and authorization design; no
such backend or web migration is implemented here.

## Live behavior

Existing Firebase staging adapters, WebRTC controller, consent prompts, room
coordinator, revocation and media-stop lifecycle remain unchanged. Home refreshes
pair/room display hints every five seconds in the foreground. Cached hints expire
after 15 seconds or at room expiry, whichever is earlier. No open/take action is
enabled without current display eligibility; the controller reauthorizes each tap.
Open/take remain explicit. Background/navigation/revocation still stop media.
No “online” presence is inferred. Expired, answered, foreign, incomplete or revoked
rooms never appear as a fresh joinable invitation.

The layout scrolls at small sizes, caps width on large devices, stacks hand
controls at accessibility text sizes, uses labelled controls and 44-point minimum
secondary actions, and provides opaque panels when Reduce Transparency is enabled.
No automatic camera, microphone, re-pair or reconnect behavior was added.

## Validation and next review

31 Python preparation/asset tests and 9 web regression tests passed locally.
All changed Swift files passed a tree-sitter syntax parse (not an iOS typecheck).
14 new XCTest methods cover availability/expiry/revocation/outsiders/answered rooms,
customizable defaults, local persistence, image import rejection and photo reset.
The 11 Foundation-only methods are included in the portable Swift harness.
No local Swift/iOS toolchain is available, so these XCTest methods have not run.
The emulator test attempt was blocked by automatic approval review over possible
external Firebase access; no fresh security-suite result is claimed.

Pending: authorized macOS compile/XCTest run and visual review at small/large
Dynamic Type sizes, VoiceOver, Reduce Motion/Transparency, selected-photo
persistence, offline/stale availability and actual two-device call/end/revoke.
No Codemagic/TestFlight build, upload or public release is authorized by this work.
Use `[skip ci]` for this branch update to suppress automatic builds.
