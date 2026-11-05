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
