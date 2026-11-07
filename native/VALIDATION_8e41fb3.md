# Approved validation: redesign source 8e41fb3

The owner approved a validation-only macOS run of application commit
`8e41fb3f24263cc5c4ea1dec6a82b58270285c76`. No build upload or distribution is approved.

## Safe manual workflow

In Codemagic choose branch `native-reach`, then workflow
**REACH validation only (8e41fb3, no upload)** (`reach-ios-validation`).
The workflow keeps the current CI/test-harness fixes and verifies with `git diff`
that `native/REACH`, `native/REACHTests` and `native/project.yml` are unchanged
from 8e41fb3. It fails before testing if any app/test/project bytes differ.
It no longer checks out the old commit and discards the corrected runner.

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

## Failure and fix

The owner-supplied Codemagic log shows **31 Python tests and 9 offline web tests
passed**, then `run-portable-tests.py` failed compiling its generated `main.swift`:
`error: no such module 'XCTest'`. The direct macOS `swiftc` invocation lacked
Apple's developer XCTest module/framework search setup. The iOS build and native
XCTest stages were skipped, not failed.

On macOS, the runner now creates a dependency-free temporary Swift package and
runs `swift test`. SwiftPM locates the Apple XCTest framework and discovers tests,
without Linux `XCTMain`/`asyncTest` wrappers. App policy sources remain in Swift 6
mode and test sources retain Swift 5 compatibility. The existing Linux runner is
unchanged. Test failures remain fatal and the generated macOS package is retained
under build logs on failure. No tests are skipped to suppress this error.

Local checks after the fix: **35 Python tests and 9 web tests passed**. The four
new regression checks cover exact source/test inclusion, macOS dispatch, failure
propagation/diagnostics and the workflow's source-identity/isolation guard.
Official Codemagic schema and workflow shell syntax also pass validation.
There is no local macOS/Swift toolchain, so a successful SwiftPM/Xcode rerun cannot
be claimed yet. The emulator suite has not been retried.

The next owner action is only to start the manual workflow above in their
existing Codemagic session and provide its run link/logs. No setup, credentials,
certificate or build-number change is needed. Do not select the TestFlight
archive/upload workflow.

After a run, record actual compile/test counts, per-method results, screenshot
review, Xcode/SDK versions and remaining failures before declaring TestFlight
readiness. Any app fixes require another validation run on the fixed source.

## Follow-up: temporary-path regression reproduced locally

The second run's step log was not available in the supplied files at the time of
this correction. Its screenshots establish Step 3 exit code 1, not the failing
command. Do not reuse the first run's XCTest error as evidence for this run.

Independently reproduced a defect in `test_portable_runner.py`:
`test_macos_test_failures_propagate_and_preserve_package` expected an unresolved
fixture executable path, while the runner intentionally resolves its compiler
path. Under a symlinked temporary directory this fails `assert_called_once_with`
with `AssertionError: expected call not found`, before any real Swift command.
The expected path is now canonicalized too, preserving all command arguments,
exit-status checks and diagnostic assertions. A dedicated symlink regression
covers the same failure on Linux as well as macOS. Production runner logic,
application/test/project source, workflow source guard and publishing isolation
are unchanged.

After correction, all 36 Python checks pass both with normal and symlinked
temporary roots; the 9 offline web tests pass. The new step log is still needed to
confirm whether this reproduced defect was the second Codemagic run's cause.
No new build, emulator run or upload was initiated.
