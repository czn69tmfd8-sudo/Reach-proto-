# REACH Build 14 — existing iPhone update: signing and recovery gate

## Confirmed from repository
- Original iOS app: `com.reachprototype.app`; XcodeGen marketing version `0.1.0`, default build `1`, overridden by CI when archiving.
- Staging Firebase only: `reach-staging-a4745`; `FirebaseBootstrap` requires exact staging project and original bundle ID. The protected `REACH_STAGING_FIREBASE_PLIST_BASE64` variable is used by `install-staging-config.py --required`. No plist is committed.
- Camera/microphone purpose strings exist; original `AppIcon` asset and privacy manifest are expected. No app-specific URL scheme or associated-domain entitlement is declared in `native/project.yml`; verify final generated Info.plist and any Firebase Auth provider callback requirements at signed archive time.
- Apple Team ID `GFUK853ZT5` and an App Store distribution signing profile are referenced by the existing Build 6 archive workflow. The old `reach-ios-device` workflow instead uses ad-hoc signing. **Neither configuration proves which channel installed the app currently on Byron's phone.**
- Codemagic references `REACH Codemagic` App Store Connect integration and `reach-staging` protected variables. This GitHub access cannot list Apple Developer/App Store Connect/Codemagic credential inventory, current signed build artifacts or installed-device provisioning.
- Known-good *source* recovery reference: `checkpoint/reach-build6-approved-source-6153bfd1` at `6153bfd1f74dcd60f1ba5fcb6cf9495b26326a17`. This is NOT an installable rollback.

## New workflow — HOLD, not authorization
`reach-adventure-single-app-signed-archive-hold` on `feature/adventure-book-single-app-integration`:
- Uses the original bundle, Apple Team `GFUK853ZT5`, existing staging plist and existing App Store signing assets; does not create credentials or change profiles.
- `REACH_SIGNED_ARCHIVE_APPROVAL` defaults to `HOLD`. It refuses to archive unless changed to `APPROVE_SINGLE_APP_ARCHIVE_ONLY` **after separate owner approval**.
- Build number defaults to `14` for preparation only. Before authorizing archive, compare with App Store Connect's latest version 0.1.0 build and choose a strictly higher unused build number.
- When authorized, it archives and validates signing and app identity; it does NOT export an IPA, upload to TestFlight, publish or install. A separately reviewed export/distribution workflow will be required.
- Do not run old Build 6 TestFlight workflow; it can upload automatically when selected.

## Before any signed build or iPhone update
1. On Byron's iPhone, locate the REACH app and open it. **Do not uninstall, offload, sign out, clear data, or reset pairing.**
2. If the app was installed using TestFlight, open **TestFlight → REACH Staging** and note its version/build, installation status, and any available older builds. If it is not listed, do not assume TestFlight installed it.
3. Open **Settings → General → VPN & Device Management**. If a developer profile is visible for REACH, note the organization/team and whether the app is enterprise/developer managed. Absence of a profile does not prove TestFlight installation.
4. In Safari, sign into Codemagic → REACH app → Build history. Find the successful signed build that Byron originally installed. Inspect its workflow, branch, commit, bundle ID, signing distribution type, build number, artifact availability/expiry and whether its signing profile is still valid. Never download/send private keys.
5. In App Store Connect (Safari) → Apps → REACH Staging → TestFlight, check the most recent build number and whether a previous internal build is still available for testing. A previous build's presence does not guarantee rollback or data preservation.
6. In Codemagic → Team settings → Code signing identities, confirm that the Apple Distribution certificate and the matching App Store provisioning profile for `com.reachprototype.app` under `GFUK853ZT5` remain valid. Confirm `reach-staging` group and App Store Connect integration exist; do not edit them without approval.
7. Confirm a recoverable previous signed IPA **and** a supported way to reinstall it, or acknowledge that no reliable rollback is established. Updating in place normally preserves sandbox data for the same signed app identity; a forced uninstall or mismatched keychain team/access group can erase local session state. A signed update cannot guarantee rollback of local data format changes.
8. Check the currently installed app's signing team and actual keychain access-group entitlement against the proposed archive before distribution. Existing Firebase pairing records are server-side and should remain untouched, but access to them depends on the preserved account/session.

## Recommended distribution path (later, separately authorized)
Prefer the **same channel as the installed app**, with original bundle ID and compatible Apple Team and keychain access groups. If TestFlight is already the installed channel and the App Store Connect app record exists, a new *internal TestFlight* build is practical, but upload is a separate approval. If existing installation is ad-hoc, an updated ad-hoc IPA signed for Byron's registered device may be safer, provided the original profile/certificate and installation channel are verified. Do not cross distribution methods blindly.

## Byron's first-device acceptance
- Confirm the old REACH is still present before update and record pairing/account state without exposing secrets.
- After explicit approval and supported in-place update, confirm only one REACH icon, no fresh onboarding, same account and pairing.
- Reach → Us → Our Adventure Book: leather/stitching/compass/clasp, opening animation, gallery, memory pages, parchment, partner stories/comments, navigation, scrolling, VoiceOver and text size.
- Staging Storage still denies reads and writes: **photo uploads remain disabled** and photo thumbnails/downloads cannot be validated until rules are separately approved and deployed.
- Check Reach, Together, Us, hand-opening/hand-taking and two-way audio/video with Aaron's unchanged app. Do not revoke or recreate the pair.
- Do not update Aaron's phone until Byron approves the outcome; then update hers and run a full two-device synchronization/calling regression.

## Current stop
No signed archive or IPA has been generated. Owner must identify installed channel/build and confirm signing asset availability, then explicitly approve archive-only work. Do not infer installation safety from green simulator tests.
