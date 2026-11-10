# Adventure Book — separate-app iPhone preview readiness (Build #12)

## Safety conclusion
The validated visual branch uses `com.reachprototype.app` and would replace an installed app with that identifier. **Do not install it over the known-good REACH.** This separate branch starts at visual commit `da00f328990cd48b8ed90010512981d753db49c3` and prepares a distinct bundle `com.reachprototype.adventurepreview`, display name `REACH Book Preview`, and an amber book icon. The original visual branch and native-reach remain unchanged.

A different bundle ID normally permits two apps on the same iPhone, **but coexistence is conditional** on an independent Apple App ID, signing profile, staging Firebase iOS app, verified callbacks/URL schemes, and an actual signed archive. None is provisioned or installed by this preparation. The current Codemagic workflow only builds/tests a simulator, with no publishing, signing identities, Firebase secrets, or TestFlight upload.

## What was inspected
- `native/project.yml`: iOS 17+, `PRODUCT_BUNDLE_IDENTIFIER=com.reachprototype.app`, `REACH Staging`, iPhone-only target, camera/microphone permission strings; simulator-only entitlement file.
- `native/REACH/Firebase/ReachEnvironment.swift`: staging project `reach-staging-a4745` and bundle identity guard.
- `native/REACH/Firebase/FirebaseBootstrap.swift`: requires Firebase plist bundle ID to match running bundle.
- `native/scripts/install-staging-config.py`: original staging plist installer requires original bundle ID; **not usable unchanged for the preview app**.
- `codemagic.yaml`: existing signed `reach-ios-device` is hard-pinned to `native-reach` and `com.reachprototype.app`; build6 App Store/TestFlight workflows also target the original identity. **Do not select any of them for this preview.**
- `native/Configuration/Simulator.entitlements`: simulator-only placeholder keychain identity, not valid physical device signing.
- Firebase photo gate stays closed: `stagingStorageRulesApproved=false` and `stagingPhotoReleaseApproved=false`. The published Storage deny-all rules block photo downloads as well as uploads.

## Isolated preview overlay
`native/scripts/prepare-adventure-device-preview.py` changes only **the temporary CI checkout**, not committed app source: XcodeGen bundle ID and display name; simulator entitlement identity; and staging-only runtime bundle guard. `native/scripts/generate-adventure-preview-icon.py` replaces the temporary checkout's icon with a clearly different amber book. These scripts do not contact Firebase or Apple and do not deploy anything.

**Fail-closed Firebase configuration:** A real preview installation needs a *new iOS app registration* in the existing Firebase staging project for `com.reachprototype.adventurepreview`. Download its own `GoogleService-Info.plist`, and privately store its base64 representation in Codemagic as `REACH_ADVENTURE_PREVIEW_FIREBASE_PLIST_BASE64`. The preview installer checks `PROJECT_ID=reach-staging-a4745`, exact bundle ID, and `STORAGE_BUCKET=reach-staging-a4745.firebasestorage.app`. It rejects the original app's plist. Never commit the plist or secrets.

**Auth/callback checks before any signed build:** Confirm the app uses anonymous Firebase Auth or otherwise register the new iOS bundle/URL callback scheme with the appropriate auth provider. Inspect any associated domains, push notifications, universal links, keychain groups, background modes, App Groups, and camera/microphone permissions. No such production entitlements should be copied blindly. Verify a preview Firebase registration and independent keychain identity do not silently sign out the original app or migrate its session.

## Native signing and distribution — not authorized or configured
The next *separate approval* would permit creation of an Apple App ID for `com.reachprototype.adventurepreview` under the owner's Apple team and a dedicated signing profile. For private registered-device installation, an ad-hoc profile must include Byron's iPhone UDID and a matching Apple Distribution certificate. Device installation also needs a trusted delivery method for the signed IPA. Alternatively a separate App Store Connect app + approved internal TestFlight build can avoid UDID collection, but **TestFlight upload is explicitly not authorized**. Neither route has been configured or tested.

Do not assume a previously installed TestFlight version can be restored. Preserve the original app and its data; avoid uninstalling, offloading or updating it. A second bundle has separate sandbox and normally separate keychain identity, but shares the staging backend; create/edit operations in the preview could change **shared** memories or pairing if pointed at the same live staging accounts. Begin with read-only inspection and avoid pairing/revocation edits.

## Simulator preflight (safe to run without Apple credentials)
In Codemagic manually select:
- Repository: `czn69tmfd8-sudo/Reach-proto-`
- Branch: `feature/adventure-book-device-isolation`
- Workflow ID: `reach-adventure-device-preview-simulator`
- Confirm the selected commit matches the latest reported SHA.
- Workflow: **REACH Adventure Book separate-app preview preflight (unsigned simulator only)**

This runs Python, portable Swift and native simulator tests after applying the isolated preview identity and icon. It produces no device-installable IPA and has no publishing section.

## Byron's first-device acceptance checklist (after separate signing/install approval)
1. On the Home Screen, verify both icons exist: the original REACH remains installed, and the amber `REACH Book Preview` appears separately.
2. Open the preview and check it explicitly identifies staging; verify no original app account/session or preferences were overwritten.
3. In **Us → Adventure Book**, inspect the leather cover, grain, stitching, compass and clasp. Check small text/VoiceOver and Reduce Motion.
4. Open the cover and inspect the gallery, card spacing, pagination, scrolling, photo placeholders and long memory titles.
5. Open a memory. Inspect parchment readability, partner stories and comments; test a short text-only memory/comment only if approved for shared staging data.
6. Check long comments, large Dynamic Type, landscape behavior, slow network, reconnect and app relaunch.
7. With Storage rules still deny-all, photo upload is disabled; photo thumbnails/downloads cannot be expected to load. Do not change rules to make the visuals pass.
8. Close preview. Reopen **original REACH** and verify its existing account, pairing, hand interactions, and audio/video call with Aaron *without installing anything on her phone*. Avoid running both apps in a call simultaneously.

## Remaining gates
- Independent staging Firebase iOS app and matching plist: **not yet created/verified**.
- Apple App ID, device registration, distribution certificate, provisioning, signed IPA, delivery: **not authorized**.
- Full native simulator preflight of this preview branch: **must pass before requesting signing approval**.
- Real-device coexistence, auth callback behavior, camera/mic permissions and calling: **not yet validated**.
- Actual original installation bundle ID and its current TestFlight/device-install source must be confirmed from the owner's device or App Store Connect; repo config alone cannot prove the installed identity.
- No Firebase rules deployment, photo activation, signing, IPA export, TestFlight upload or installation was performed.
