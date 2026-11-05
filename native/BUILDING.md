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
