# WebRTC dependency decision

Do not add a WebRTC binary to the native target until the baseline project has a
verified macOS compile.

Current research shows multiple actively published XCFramework distributions,
including Jitsi's Swift Package binary. The underlying Google WebRTC native
project remains the source implementation.

Selection criteria for REACH:

- current iOS device + simulator slices
- Swift Package Manager support
- recent upstream WebRTC branch
- reproducible version pinning/checksum
- acceptable license
- active maintenance
- compatible with cloud/macOS CI
- no vendor signaling lock-in

REACH owns its signaling contract in `WebRTCSignalingContract.swift`; the
selected library will implement media/peer-connection behavior behind that
boundary. Firebase signaling remains independent of the WebRTC binary.

Production reliability also requires TURN. STUN-only success in development is
not considered sufficient for release.
