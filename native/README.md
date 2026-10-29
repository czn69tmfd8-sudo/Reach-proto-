# REACH Native

Native iOS development lane for REACH.

This branch is intentionally isolated from web production and web staging.

## Product contract
REACH is not "start a video call." A person intentionally opens a REACH session for an already-authorized partner; that partner can later take their hand without waking the opener.

## Initial architecture
- SwiftUI application shell
- Reach / Together / Us navigation
- Domain models isolated from Firebase/WebRTC implementations
- Pairing/session service protocols so the formal web call test can inform native behavior without restructuring the app
- Native media implementation follows after the formal two-phone test

Web production remains the reference implementation until native behavior is validated.
