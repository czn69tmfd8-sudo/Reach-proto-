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

## Native staging transport (November 2026)

The simulator baseline passed 62 tests. The Staging tab now owns an actual
RTCPeerConnection with microphone and camera tracks, SDP/ICE over Firestore,
remote video rendering, and explicit foreground-only joining. The dependency is
pinned to stasel/WebRTC 140.0.0 (device arm64 and simulator arm64/x86_64).
A connected transport callback reports media transport connectivity; it is not a
claim that two humans verified audio/video. No TURN relay is provisioned. Test
first on two physical iPhones on the same Wi-Fi, then separate networks. Cellular
reliability requires a separately approved TURN deployment or existing credentials.
The original home is isolated in the Demo tab; the default Staging tab is for
live testing. No overnight auto-join is enabled.
