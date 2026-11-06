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

### Remote ICE drain and Linux runtime investigation

The remote inbox now grants only one drain owner per room. Incoming ICE remains
queued while an SDK add callback is pending. New listeners cannot apply candidates
concurrently or overtake the buffered queue; stale owners cannot consume a fresh
room's queue. The inbox refuses to mark an absent SDP as applied.

A recurring local Linux harness SIGILL was observed during the initial validation
cases, before the new inbox cases. A minimal XCTest startup program passed;
loader mappings and offline disassembly now identify the trap as Swift 6.0.3
libdispatch `_dispatch_workq_monitor_pools.cold.1` (offset 0x212f0). The branch
reaches that trap when opening a registered worker's `/proc/<tid>/stat` fails.
This establishes the failing runtime path, but not why that worker stat is
unavailable. A separate async XCTest with a one-second Task.sleep passed, so a
blanket async-XCTest failure is not established. Syscall tracing was blocked
by the environment's ptrace restriction. Portable-runner failures now preserve the
executable, module/library, generated test entry point and failure metadata under
ignored build-logs/portable-failure. Failures remain failures; no automatic retry
or test bypass is introduced. Use Codemagic's native results as the iOS build gate.

See TWO_IPHONE_TEST_PLAN.md for the physical call gates and acceptance scenarios.

For the next Linux reproduction, set `REACH_PORTABLE_LOADER_TRACE=1` on the
portable runner. On failure it preserves loader mapping files alongside the
harness. This is diagnostic only: it does not modify dispatch, skip tests or
retry. Upstream reference: swift-corelibs-libdispatch, swift-6.0.3-RELEASE,
`src/event/workqueue.c`, `_dispatch_workq_count_runnable_workers`.

### Signed device archive gate

Before ad-hoc export, the verifier decodes the embedded provisioning profile and
requires a future expiration date, exact app identity, matching team, registered
devices and distribution entitlements. Store, enterprise, development and
wildcard profiles are rejected by this ad-hoc workflow. The owner must still
confirm both phones' UDIDs are included; the repository does not contain them.
No signed archive or physical-device installation has been verified yet.

Validation on 2026-11-06: 69 Firestore emulator checks, 16 Python configuration/
archive checks and 9 web recovery checks passed. The portable Swift 6 application
library compiled, but the full Linux test process reproduced SIGILL at the same
dispatch offset; this run is failed, not a passing 106-test result. Loader trace
preservation was verified. Codemagic Build #11 passed on 1c60ac1 according to the
owner; 18041be and these changes still require macOS validation.

### Call startup choices and runtime isolation follow-up

Mute and video transmission choices now persist while permission, factory and
camera setup suspend. Tracks receive the current choice before attachment to the
peer. Ending the peer disables and detaches the controls; late toggle/binding
callbacks cannot enable a closed session. Six portable tests cover setup choices,
independent controls, replacement and terminal closure. A real-SDK track test is
included in the native simulator suite and still needs macOS execution.

In this follow-up, the full portable suite passed 112/112 in one run, with strict
Swift 6 application compilation. The 69 emulator, 16 script and 9 web recovery
checks also passed. Separate standalone dispatch and pthread probes establish
that live worker proc entries are missing in this Work Linux environment; see
scripts/diagnostics/README.md for evidence and reproduction sources. This is an
environment-level reproduction, not evidence of the same defect on GitHub-hosted
Ubuntu or on iOS. No runtime patch, suppressed failure or automatic retry is used.

Codemagic remains configured for push events on native-reach, including simulator
launch/tests and unsigned physical-device compilation. No new macOS result is
claimed here; the owner-confirmed last successful build is #11 on 1c60ac1. Firebase
authentication and rules deployment remain paused; no signed phone install or
physical audio/video call has been verified.
