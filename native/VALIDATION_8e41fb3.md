# Approved validation: redesign source 8e41fb3

The owner approved a validation-only macOS run of application commit
`8e41fb3f24263cc5c4ea1dec6a82b58270285c76`. No build upload or distribution is approved.

## Safe manual workflow

In Codemagic choose branch `native-reach`, then workflow
**REACH validation only (8e41fb3, no upload)** (`reach-ios-validation`).
The workflow checks out the exact approved application source before executing.
Its configuration is carried by a later CI-only branch commit; the app source
under test is still exactly 8e41fb3.

It has no automatic trigger, Apple integration, signing identities, environment
variable groups, publisher, archive export or upload step. It does not install a
Firebase client plist and fails if one is present. Simulator tests run without
live Firebase configuration; the app launch is an offline/unpaired visual check.
The blocked Firestore emulator suite is deliberately omitted.

The run performs:

1. Packaging/photo-integrity tests, offline web tests and portable Swift tests.
2. Full iOS simulator XCTest execution, including all 14 new redesign methods.
3. A log gate requiring a passing result for each new method.
4. Compiled Assets.car/privacy-manifest presence checks and a launch screenshot.
5. Release compilation for generic iPhone with distribution signing disabled.
6. Log and xcresult artifacts only; no IPA is exported or uploaded.

## Current result

No macOS run has started from this environment. The GitHub connector has no
workflow-dispatch action, and the cloud browser is signed out of GitHub.
Local packaging validation passes (31 tests). Workflow schema/shell validation
must pass before committing this configuration; this is not an iOS build result.

The next owner action is only to start the manual workflow above in their
existing Codemagic session and provide its run link/logs. No setup, credentials,
certificate or build-number change is needed. Do not select the TestFlight
archive/upload workflow.

After a run, record actual compile/test counts, per-method results, screenshot
review, Xcode/SDK versions and remaining failures before declaring TestFlight
readiness. Any app fixes require another validation run on the fixed source.
