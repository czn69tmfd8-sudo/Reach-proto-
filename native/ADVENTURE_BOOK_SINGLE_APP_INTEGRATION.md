# REACH Build 13 — ONE-app Adventure Book integration and release hold

## Source and scope
- Integration branch: `feature/adventure-book-single-app-integration`, created from the owner-validated visual commit `da00f328990cd48b8ed90010512981d753db49c3`.
- Original bundle identifier: `com.reachprototype.app`. No second bundle, independent Firebase registration or Apple App ID.
- Existing app has three tabs in `RootView.swift`: Reach, Together, Us. `ReachUsView` contains `NavigationLink { ReachAdventureBookLive() }` and retains all other Us sections, sample design, and existing memories.
- The original `native-reach` branch is an ancestor of the visual commit, but the visual branch includes additional UI and Adventure Book feature changes; it is **not yet approved for merging**.
- The source rollback reference `checkpoint/reach-build6-approved-source-6153bfd1` pins commit `6153bfd1f74dcd60f1ba5fcb6cf9495b26326a17`, referenced by the historical signed Build 6 workflow. The actual installed iPhone binary/version has **not** been identified or verified as this exact commit. Do not equate source rollback with device rollback.

## Existing distribution
- `codemagic.yaml` includes `reach-ios-device`: manually initiated ad-hoc signed IPA for `native-reach` only; requires Codemagic `reach-staging` secret group and existing signing identities. It is NOT suitable for this integration branch without a separate reviewed workflow.
- `reach-ios-build6-archive-only` and `reach-ios-build6-testflight` are pinned to Build 6 and the original branch; **do not use them** for Build 13. TestFlight upload is not authorized.
- Existing Apple Team ID in build configuration: `GFUK853ZT5`. Its continued validity, installed signing team, distribution channel, and provisioning status must be verified with the owner's Apple/Codemagic account before preparing a signed archive.
- Existing `native/project.yml` uses `com.reachprototype.app`, display name `REACH Staging`, iOS 17+, camera/microphone usage strings, and simulator-only entitlements. `ReachEnvironmentGuard` enforces `reach-staging-a4745` and the original bundle. The original staging plist installer remains unchanged.
- The Firebase Storage release gate remains closed (`stagingStorageRulesApproved=false`, `stagingPhotoReleaseApproved=false`). Published deny-all Storage rules mean authenticated thumbnails cannot load yet; do not activate uploads or change rules for the visual test.

## Validation gate
- Codemagic workflow `reach-adventure-single-app-validation` is a **new, unsigned, no-publishing** integration preflight. It validates the exact original bundle identity, hydrates historical Git commits, runs protected-file checks, Python and portable Swift suites, isolated Firestore/Storage emulator tests, native simulator XCTest, and an unsigned physical-device compilation.
- The owner-confirmed Build 11 result is 207/207 native simulator tests passed on the original visual checkpoint. **Build 13 has not yet passed Codemagic.** Do not report success until its logs confirm it.
- No Firebase deployment, signing, IPA distribution, TestFlight upload, installation, photo activation, or merge is included in this workflow.

## Device update and rollback precautions
1. On Byron's iPhone, record the current installed REACH build/version and whether installed through TestFlight or ad-hoc provisioning. Check Codemagic or App Store Connect for a *currently retrievable* known-good signed IPA/TestFlight build, exact bundle/team, provisioning and build number. Do not uninstall, offload, reset or replace anything.
2. Confirm the signing identity and distribution channel of the installed app. A same-bundle app update may preserve the app sandbox and keychain when installed as a compatible update, but **it is not guaranteed across differing signing teams, keychain access groups, uninstall/reinstall, or distribution channels**.
3. Verify a supported rollback method BEFORE updating. Older TestFlight builds are not necessarily installable, and ad-hoc rollback requires an available, valid signed IPA/profile and compatible device.
4. Existing app and Adventure Book both use staging Firebase, so a new version may write shared data. Begin with visual/read-only checks; do not revoke/re-pair, clear sessions, or edit shared records until separately approved.
5. After an explicitly authorized build, update only Byron's phone. Verify launch, current account, pairing, Us → Adventure Book, leather/stitching/compass/clasp, gallery/photo placeholders, parchment, stories/comments, page navigation, accessibility, scrolling and performance.
6. Verify Reach/Together/Us, hand interactions, audio/video call with Aaron on her unchanged app. Only after Byron confirms the update should Aaron's phone be considered for updating and paired-device regression.

## Owner approval gate
Before a signed build: Codemagic unsigned integration preflight must pass; installed app channel/team/build and verified recovery route must be identified; user must explicitly approve signing and a separate integration archive workflow. Upload/distribution/installation each require their own authorization. Do not ask for credentials in chat.
