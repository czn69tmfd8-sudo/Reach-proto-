# Native REACH build gates

## Gate 1 — architecture
- [x] Native SwiftUI shell
- [x] Reach / Together / Us navigation
- [x] Session domain model
- [x] Explicit connection state machine
- [x] Permission boundary
- [x] Audio-session boundary
- [x] Screen-awake controller
- [x] Production Firestore contract mapped read-only
- [x] Existing web anonymous-identity migration risk documented

## Gate 2 — buildable iOS target
- [ ] Generate/validate Xcode project
- [ ] Add camera and microphone privacy descriptions
- [ ] Establish bundle identifier
- [ ] Compile against supported iOS SDK
- [ ] Run unit tests for state machine

## Gate 3 — isolated native backend
- [ ] Firebase iOS app registration
- [ ] Firebase Auth adapter
- [ ] Firestore pairing adapter
- [ ] Native test environment only
- [ ] Identity migration rehearsal

## Gate 4 — media
- [ ] Choose native WebRTC transport implementation
- [ ] Implement local capture
- [ ] Implement offer/answer signaling
- [ ] ICE candidate exchange
- [ ] TURN strategy
- [ ] reconnect behavior
- [ ] two-device native call

## Gate 5 — distribution
- [ ] Apple Developer membership
- [ ] App Store Connect record
- [ ] signing/capabilities
- [ ] TestFlight build
- [ ] Byron install
- [ ] Aaron install

Production web remains untouched until its formal call test is complete.
