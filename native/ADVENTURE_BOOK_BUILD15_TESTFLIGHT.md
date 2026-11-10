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
| Default approval input | `HOLD` |

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
   in private CI artifacts. It has no IPA export step or publisher.
5. Review `build15-signing.json` from the private job. Compare the signed team,
   application identifier (including prefix), Keychain access groups, and app
   groups to the signed Build 7 artifact or trusted signing record. The archive
   verifier checks profile expiry, the signed identity, authorization of the
   actual leaf certificate and Keychain groups, and the staging plist. A
   matching team and bundle alone do not prove session continuity. If Build 7
   evidence is unavailable, record that uncertainty before authorizing upload.
   Use only a signed-in, restricted artifact view. Never share signing secrets
   or create a public artifact link.

App Store Connect upload and internal assignment require separate approval.
The existing production/release workflows are outside this integration branch's
release path. Once separately authorized, export the reviewed archive for
internal TestFlight only, verify its packaged identity again, upload to the
existing REACH Staging listing, and assign only Byron for the first update.
If the existing internal group distributes builds automatically to Aaron, use
a Byron-only assignment or keep automatic assignment off for this build under
separate approval. Aaron should keep her existing installation until Byron
approves her update.

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
