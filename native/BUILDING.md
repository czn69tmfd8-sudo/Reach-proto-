# Building native REACH

The project definition lives in project.yml. The generated Xcode project is intentionally not committed.

## Generate
Install XcodeGen 2.46 or later, then from this directory run:

    xcodegen generate

## Build gate
For an unsigned simulator build:

    xcodebuild -project REACH.xcodeproj -scheme REACH -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build

For tests, choose an available iOS Simulator destination and run the REACH scheme tests.

## Privacy
The generated app target includes the required camera and microphone usage descriptions. REACH requests those permissions only when preparing an intentional connection.

## Signing
No signing certificate, Apple team ID, provisioning profile or Firebase environment file belongs in Git. Those are injected only in trusted build/distribution environments.

## Current bundle ID
com.reachprototype.app is a temporary development identifier. Do not register it as the final App Store identity without an explicit product decision.

### Simulator runtime signing and WebRTC tests

The Codemagic simulator workflow now uses local ad-hoc signing (`CODE_SIGN_IDENTITY=-`).
This needs no Apple account, certificate, provisioning profile, or paid membership.
The simulator-only `Configuration/Simulator.entitlements` gives the test host an
application identifier and a private keychain group; the former unsigned runtime
reported Firebase `SecItemCopyMatching (-34018)` and could not persist identity.
These settings are conditional on the simulator SDK and do not authorize device
installation or TestFlight. `KeychainAccessTests` verifies actual local credential I/O.

The WebRTC regression test uses the SDK's injectable audio-device API to isolate
SDP negotiation from the hosted simulator's unavailable CoreAudio backend. Both
real peers still create audio/video tracks, generate/apply offer/answer, check
DTLS fingerprints and stable signaling, and close. It does not prove PCM delivery
or a two-iPhone call. Device builds keep the default native audio backend.
Factory initialization runs off MainActor, and all SDK callbacks have deadlines.
The hosted unit-test app does not automatically sign in to live staging.

### Physical iPhone preparation

See `DEVICE_INSTALLATION.md` for the manual registered-device IPA workflow and
exact Apple signing/TestFlight prerequisites. The normal simulator workflow also
compiles device-only code without signing. The device workflow does not publish.
All configuration injection uses `scripts/install-staging-config.py`; device builds
require the validated staging client plist. Automatic CI runs only mocked Auth
smoke-test unit tests; the live check requires an explicit `--live-staging-test`
invocation and is never run on every push.

### Portable verification without Xcode

Run `python3 scripts/run-portable-tests.py` with Swift installed (or set `SWIFTC`).
It compiles portable application policies in Swift 6 mode and runs their XCTest
suite; it does not compile Firebase, UIKit, Keychain or the real WebRTC SDK. Those
remain part of the full Codemagic simulator suite. Linux XCTest discovery uses
Swift 5 compatibility mode for its wrappers.

Real transport failure closes media immediately. Negotiation after a remote SDP
arrives is bounded to 45 seconds; a disconnected established transport has a
20-second recovery window. Reconnection cancels the deadline, and stale callbacks
cannot stop a recovered/new call. Waiting for a partner to explicitly take an
open hand does not start the negotiation timeout. Terminal failure ends the old
room; retry requires an explicit fresh open/join, never silent auto-joining or
reusing old SDP/ICE. These policy tests do not prove physical media transport.

### Device camera startup and cleanup

The device-only `WebRTCCameraCaptureDriver` calls WebRTC's explicit
`stopCapture(completionHandler:)` overload. A bare `stopCapture()` in an async
function selects the imported async overload and caused the unsigned iPhone
compile to fail. Camera startup/shutdown requests and mutable ownership now live
in `CameraCaptureLifetime` on MainActor. Close disables peer tracks immediately,
cancels a pending startup continuation, and requests hardware shutdown without
blocking the UI. The driver remains retained through the stop completion.
A late startup callback after close requests another stop; it cannot revive the
peer. Failed, timed-out or cancelled preparation closes the peer, and a second
concurrent preparation cannot replace an in-flight capture.

Portable tests inject a controllable camera driver to cover these races and
retention. They do not replace the real device SDK compile or physical camera
verification. Keep both simulator tests and unsigned physical-iPhone compilation
enabled in Codemagic. No signing credentials are needed for that compile step.

SDP completion closures are explicitly `@Sendable`, capture only the synchronized
continuation deadline and immutable values, and do not mutate peer/UI state from
worker threads. Firestore room transaction return values are explicitly discarded;
optional post-revocation housekeeping uses its async API in an independent task.
Revocation still commits authorization first and never waits for housekeeping.

### Offline session cleanup

Ending capture remains immediate. The call controller waits at most 15 seconds
for Firebase session cleanup, then releases its busy state and reports that server
confirmation is missing. Cleanup may complete later, but remains bound to the
original room/pair and cannot clear a newer room pointer. A timeout never means
server cleanup succeeded or that a new call has authorization. Reconnect and
refresh/close the old hand before retrying. Four portable tests cover success,
server rejection, timeout with late completion, and a cancelled calling task.

### Local ICE publication

Each one-shot room owns a bounded local candidate outbox. Candidates are validated
and deduplicated before serial Firestore publication; replayed SDK callbacks do
not issue duplicate writes. The lifetime cap is 512 unique candidates, including
already published entries. Overflow stops media instead of accumulating tasks.
End resets the queue; generation guards prevent an old drain from publishing a
new room's candidates. This does not implement ICE restart into an old room.
