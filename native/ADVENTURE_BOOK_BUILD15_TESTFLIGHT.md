# REACH Staging Build 15 preparation

Use the single app already installed through internal TestFlight. The approved
application source is commit `9109f8b4aeefd7f29d497c2540be0319b21b59e3`.
The archive gate compares the application, XCTest sources, configuration and
project to that exact source fingerprint before the staging plist is injected.

| Item | Expected |
| --- | --- |
| Branch | `feature/adventure-book-single-app-integration` |
| Workflow | `reach-adventure-single-app-signed-archive-hold` |
| App | REACH Staging, `com.reachprototype.app` |
| Apple team and profile type | `GFUK853ZT5`, App Store distribution |
| Firebase | `reach-staging-a4745` via the existing `reach-staging` group |
| Version | `0.1.0 (15)`, provisional until confirmed unused |
| Default approval input | `UPLOAD_INTERNAL_BUILD_15` (owner-authorized manual upload) |

## Before authorizing a private archive

1. In iPhone Safari, open [App Store Connect](https://appstoreconnect.apple.com/),
   then **Apps → REACH Staging → TestFlight → iOS → Builds**. Check version
   **0.1.0** and its upload history, including processing uploads. Confirm build
   **15** is unused and no already uploaded build is numbered 15 or higher.
   If it is taken or superseded, stop and choose a higher number in a reviewed
   change. Do not remove or expire builds.
2. Open **TestFlight → REACH Staging**. Confirm **0.1.0 (7)** is installed and
   expand **Previous Builds → 0.1.0** to confirm **(6)** has **Install**.
   Record any expiry shown for either build. Your prior confirmation establishes
   the working installation and earlier availability. Access must still be
   checked immediately before updating.
3. In Codemagic **Team settings → Code signing identities**, verify the existing
   App Store profile for the exact bundle and an unexpired Apple Distribution
   certificate for the team. Under **Team integrations**, check the existing
   **REACH Codemagic** App Store Connect integration. Verify that the REACH app
   has access to the existing staging environment group. Leave the values,
   profiles, Apple records, and certificates in place.
4. After the owner explicitly authorizes archive-only work, choose **Start new
   build**, the integration branch, and the workflow above. Verify its commit,
   then choose **APPROVE_SINGLE_APP_ARCHIVE_ONLY**. This reruns 207 native tests
   before introducing the staging plist, uses the existing signing identities,
   validates internal-only local export options, and produces a signed archive
   in private CI artifacts. The archive-only choice exits before IPA export or upload.
5. Review `build15-signing.json` from the private job. Compare the signed team,
   application identifier (including prefix), Keychain access groups, and app
   groups to the signed Build 7 artifact or trusted signing record. The archive
   verifier checks profile expiry, the signed identity, authorization of the
   actual leaf certificate and Keychain groups, and the staging plist. A
   matching team and bundle alone do not prove session continuity. If Build 7
   evidence is unavailable, record that uncertainty before authorizing upload.
   Use only a signed-in, restricted artifact view. Never share signing secrets
   or create a public artifact link.

## Authorized internal upload using the existing workflow

Owner authorization on November 10, 2026 permits Build 15 export, upload and
internal availability. No installation, external beta review, public App Store
release or Firebase changes are included.

Previous successful Codemagic runs were started by the owner from Safari using
the existing GitHub-connected app. The GitHub connector can prepare this branch,
but it does not provide a Codemagic API token or a Codemagic build trigger.
The existing Apple integration remains stored in Codemagic. Cloud Browser
GitHub/passkey authentication is not required for an owner-started Safari run.

Use **Start new build → feature/adventure-book-single-app-integration →
reach-adventure-single-app-signed-archive-hold**, from the reviewed preparation
commit. Select **archive_approval → UPLOAD_INTERNAL_BUILD_15**. Selecting `HOLD`
rejects the run, and `APPROVE_SINGLE_APP_ARCHIVE_ONLY` still produces only the
private archive. Do not select an older Build 5/6 uploader.

This extends the same successful archive workflow. It reproduces the reviewed
app source from `04442aeba6013623f2e25dbe4caf072e5c4c829d`, requires its exact
source fingerprint, reruns all 207 tests, and uses the existing signing assets.
It then locally exports the signed archive with `testFlightInternalTestingOnly`
and fixed version/build settings. Only a verified IPA reaches the upload command.
Reproduction avoids requiring a new credential or public URL to download the
previous private Codemagic artifact. The original archive remains recoverable.

The existing `REACH Codemagic` integration supplies the upload credentials.
Missing credentials fail preflight without displaying values. The upload uses
Codemagic's installed CLI with package validation enabled. It does not request
external beta review, App Store review, build expiration or group changes.
Ambient App Store Connect CLI options are removed before upload. Apple processing
and compliance are not inferred from command success.

After successful upload, in Safari open **App Store Connect → Apps → REACH
Staging → TestFlight → iOS → 0.1.0 (15)**. Wait for processing and review any
compliance request. Do not guess a new encryption declaration. Confirm the
existing internal **REACH Internal** group can access the build, adding it there
if necessary. Do not change external groups or expire earlier builds. Group
availability does not authorize installation on Aaron's phone. Aaron keeps
Build 7 until Byron's first-device acceptance and separate update authorization.

Download the private `build15-upload-result.json`, `build15-signing.json` and
export log if further verification is required. A successful CLI receipt records
only upload-command success, with processing and tester availability pending.
No new build has been started from this preparation environment.

## Recovery on Byron's iPhone

If Build 15 causes problems, stop writes and capture the build number and
privacy-safe symptoms. After separate approval, open **TestFlight → REACH
Staging → Previous Builds → 0.1.0 → Build 7 → Install**. Use Build 6 only as a
secondary fallback if Build 7 is unavailable and Build 6 still has **Install**.
Install over the existing app. If TestFlight asks to remove the app or the
older build is unavailable, stop and preserve the current installation. After
rollback, check **About REACH**, the existing account, pairing, and a call.

An older binary replaces the executable. It does not rewind the app sandbox,
Keychain, Firestore writes, or Storage. Data or settings written by a newer
build can be incompatible with an older binary. Availability can also change
with TestFlight expiry, tester assignment, or a build being expired by an
administrator. Do not uninstall, offload, sign out, clear data, or revoke the
pairing as a recovery step. Keep the existing Build 6 source checkpoint and
Build 7 distribution record.

## First-device acceptance

1. After separately authorized upload and installation, Byron updates in place
   from **TestFlight → REACH Staging → Update**. Aaron stays on her current build.
   Confirm one REACH app, version 0.1.0 (15), the existing account and pairing,
   and the Reach, Together and Us tabs. Begin without writing shared data.
2. From **Us → Our Adventure Book**, inspect the cover, leather/stitching/compass/
   clasp, opening, gallery layout and placeholders, parchment pages, story and
   comment navigation. Check scrolling, page movement, text size, VoiceOver,
   and responsiveness. The photo gate stays closed, with uploads and live
   photo downloads unavailable under the deny-all Storage policy. If staging
   Firestore denies Adventure Book operations, record the displayed result.
   Emulator permissions do not establish live availability.
3. With Aaron on her existing build, test both hand directions and an actual
   two-way audio/video call. Verify both can see and hear each other, toggle
   mic/camera, and end the call from either side. Check existing Together and
   shared interactions. Leave pairing and authentication untouched.
4. Once Byron authorizes Aaron's update, repeat the two-phone call, navigation,
   and synchronization checks. Where staging authorizes the book, use
   clearly labeled test memories and confirm separate stories and comments
   appear on both phones without overwriting one another. Gallery photos stay
   out of scope. Report the build, failing action and fixed error text without
   account IDs, codes, photos, video, or raw logs.

## Approval-mode correction after Codemagic build index 2

The downloaded export/upload log contains only “Archive-only selection: no
export or upload.” At preparation commit `0f38e98`, this message is reachable
only when the effective environment value is exactly
`APPROVE_SINGLE_APP_ARCHIVE_ONLY`. An absent, unresolved or upload value would
not produce this successful skip. That log alone cannot distinguish a retained
UI selection from a Codemagic environment override.

The manual workflow now defaults to the already-authorized
`UPLOAD_INTERNAL_BUILD_15`. Both the initial gate and export/upload step export
the same resolved workflow input directly, so a stale environment mapping cannot
silently select archive-only mode. Both steps log the non-secret effective mode.
The real export shell is regression-tested with harmless command stubs for
upload, archive-only, missing, HOLD and unresolved values, including a stale
archive-only environment overridden by the selected upload input.

Start a **new build**, not a rebuild of index 2. Select the current preparation
commit and ensure **archive_approval = UPLOAD_INTERNAL_BUILD_15**. The first step
must show **Build 15 effective approval: UPLOAD_INTERNAL_BUILD_15** before tests
and signing begin. The export step must show the same mode. This is a local
execution check of the workflow shell, not a claim that the new Codemagic run
or Apple upload has occurred.
