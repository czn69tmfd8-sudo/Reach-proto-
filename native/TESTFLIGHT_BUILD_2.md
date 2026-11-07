# REACH Staging 0.1.0 (2): preparation only

Application/project baseline: `8e41fb3f24263cc5c4ea1dec6a82b58270285c76`.
Validation harness/test fixture baseline: `da12e4291dc6e44dc5e3d70d608ea1f8dca2eb99`.
The app and project remain byte-identical to the approved baseline. The only native
test deviation is the reviewed immutable outsider fixture permitted by the source verifier.

## Manual Codemagic selection after separate upload approval

- Repository: `czn69tmfd8-sudo/Reach-proto-`
- Branch: `native-reach`; select the preparation commit containing this document.
- Workflow ID: `reach-ios-testflight-archive`
- Display name: `REACH staging TestFlight (manual build, automatic upload)`
- `REACH_IOS_BUILD_NUMBER`: `2` (workflow default; any other value is rejected)
- Marketing version: `0.1.0` (archive command override; project source is unchanged)
- Bundle: `com.reachprototype.app`; Apple team: `GFUK853ZT5`
- Existing App Store Connect integration: `REACH Codemagic`
- Existing variable group: `reach-staging`
- Signing: existing matching App Store provisioning profile and Apple Distribution
  certificate/private key. No new credentials or settings are required by this change.

Starting this workflow archives and automatically uploads its verified IPA to App
Store Connect. It does not submit for public review/release or beta review and does
not automatically assign testers. After processing and export compliance, select
0.1.0 (2) in the existing `REACH Internal` internal testing group, then update in
TestFlight on each iPhone. This workflow has no automatic build trigger.

## Source, design and staging checks

The archive's first step verifies approved app/project bytes before installing the
existing staging client plist. The installer and archive verifier require
`reach-staging-a4745` and the exact bundle ID. No Firebase administrative action,
rules deployment, Authentication setting change or data modification is performed.

The source includes the redesigned Reach/Together/Us navigation, two circular
local profile photographs, connecting heart pulse, separate open/take actions,
and local names, optional message and photograph customization. App/service code,
consent, revocation, pairing and WebRTC implementations are unchanged by this
preparation. Customization is device-local; the heart is a pairing indicator,
not proof of online presence or connected media.

The default photograph is the exact original `staging/Reach back.png`, copied
without reencoding into `OriginalSunset.imageset/ReachSunset.png` (864 x 1536).
SHA-256: `b1b72b03ca4f7d331daec329edf39c67136e7ae09daa180ac11b62a56a3f8efc`.
Packaging tests compare all bytes and the catalog reference. Export verification
requires nonempty compiled Assets.car, privacy manifest, camera/microphone purpose
strings and app icon, plus exact version/build, staging config and valid signing.
It does not claim the source PNG hash is the hash of Xcode's compiled asset catalog.

## Evidence and remaining limits

The owner reports the da12e42 validation-only run completed packaging checks,
project generation, native XCTest, compiled-resource verification and physical
phone compilation. The workflow's successful XCTest step requires passing log
entries for all 14 redesign methods. However, the new full logs, test-summary.json,
xcresult and simulator screenshot were not available for independent inspection:
the available Codemagic session requires login, and the latest supplied screenshots
list the stages but do not provide exact XCTest totals. Do not describe expected
test counts as observed results. Review the successful run's source-verification
log, test-summary.json/tests.log and redesign-tests-verified.txt, device compile log
and redesign-launch.png before authorizing upload. Older local run logs are not
evidence for this successful redesign run.

Preparation verification: 43 Python checks and 9 offline web tests pass; YAML
parsing, all workflow shell syntax, source identity, original photo identity and
unchanged non-TestFlight workflows pass. No local Swift/Xcode toolchain exists;
no new macOS run or Firebase emulator retry was performed.

Signing/integration and `REACH Internal` are preserved from the previously completed
setup; their live validity/membership cannot be independently reconfirmed from the
repository. The archive checks the installed profile, exact team/bundle, expiration,
distribution entitlements and actual codesign signature before promoting an IPA.
Confirm Build 2 is still unused in App Store Connect. The validation run excluded
live Firebase configuration; the archive includes the existing staging-only plist.
Firebase dependencies use a version range, so fresh package resolution can differ
from the validation run; inspect the archive package-resolution log. Export
compliance may need to be answered again for this build. No encryption declaration
was changed. Genuine two-phone audio/video, permission prompts and physical layout
still require device testing; STUN-only connectivity can fail on restrictive
networks because TURN has not been provisioned. Do not bypass consent or revocation
to complete these checks.

No build, upload, tester assignment or public submission is authorized by this
preparation commit. Obtain the owner's separate approval before starting the
uploading workflow.
