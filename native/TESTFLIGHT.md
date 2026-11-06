# First private TestFlight build — staging only

## Current boundary

The owner confirms Apple Developer membership is active through November 6, 2027,
and App Store Connect access is available. Bundle identifier remains
`com.reachprototype.app`; the installed display name is **REACH Staging**.
The app requires iOS 17 or later. No public App Store release, pricing,
subscriptions, billing change or new purchase is part of this preparation.

The owner manually published the hardened staging Firestore rules on November 6,
2026 at **10:02 AM as displayed in the console**. The supplied full readback
matched `7e62b5e95f939d56155ce047634ead33023dfd1e6b35a6e20cb3601c7ddc00b8`.
This is owner-supplied evidence, not an independent authenticated download.
The older 8:28 AM d23ac0d8 version is retained as rollback. No rule changes occur
in this distribution work. Firebase Authentication remains paused; no sign-in
provider is enabled or live sign-in initiated by these scripts.

## Prepared workflow and checks

`reach-ios-testflight-archive` in `codemagic.yaml` is **manual build, automatic
App Store Connect upload**. Do not start it until the owner explicitly approves
that build and upload. No automatic trigger is configured for this workflow.
The simulator and ad-hoc workflows have no publisher and are unchanged.

The owner confirms the REACH Staging App Store Connect record exists, the
**REACH Codemagic** API integration is configured and the **REACH Distribution**
Apple Distribution certificate has been generated. This workflow references that
integration, selects existing `app_store` signing assets for
`com.reachprototype.app`, and pins Apple team **GFUK853ZT5**. It does not create
or revoke certificates/profiles. The matching certificate private key must be
available in Codemagic, together with a valid App Store Connect provisioning
profile for this exact bundle and team. A certificate alone is insufficient.

The publishing block uploads the verified IPA automatically after a successful
manual build. `submit_to_testflight: false` disables automatic **beta review**,
not binary upload; the uploaded build appears in App Store Connect/TestFlight
when Apple finishes processing. No beta groups or invitations are configured.
`submit_to_app_store: false` disables public App Store review submission. No
public release, pricing, subscriptions or billing settings are changed.

| Input | Required value |
| --- | --- |
| REACH_STAGING_FIREBASE_PLIST_BASE64 | Existing protected reach-staging group value for the staging iOS client; required and never printed |
| REACH_APPLE_TEAM_ID | GFUK853ZT5, pinned in this workflow and checked before tests/archive |
| REACH_IOS_BUILD_NUMBER | Next unused integer, 1–9999, for version 0.1.0; set in reach-staging |

Never paste private keys, passwords or signing files into chat or GitHub.
No Firebase registration, provider enablement or data changes are performed.

The workflow validates branch, team, inputs and Python checks, generates the
Xcode project, runs native simulator tests, applies existing App Store profiles,
archives for iPhone and verifies staging bundle/project and signing team. Export
options must contain only the REACH profile and the exact team. Export remains
local, with symbol upload disabled. The IPA is initially quarantined outside
publisher artifacts, then unpacked and verified for signature, profile, staging
configuration, build number, icon, privacy manifest and camera/mic descriptions.
Only after verification is it atomically promoted to the publisher's artifact
path. Old output is removed at preflight. Failed verification leaves no IPA for
the publisher, even if artifact collection runs after a failed script.

The icon reuses the web heart geometry on an opaque background. The own-app
privacy manifest declares UserDefaults access (`CA92.1`). SDK manifests, privacy
disclosures and encryption/export-compliance answers still require review. No
`ITSAppUsesNonExemptEncryption=false` answer is guessed for Firebase/WebRTC.

## Remaining owner checks on iPhone — do not start a build yet

1. In Codemagic → Team settings → Code signing identities → iOS provisioning
   profiles (under codemagic.yaml settings where shown), inspect the existing
   profile. It must show **App Store / App Store Connect**, exact bundle
   **com.reachprototype.app**, team **GFUK853ZT5**, a future expiry and a matching
   Apple Distribution certificate/private key. A screenshot of the non-secret
   profile summary is enough to confirm this; do not share the downloaded file.
2. If no matching profile exists, use Apple Developer → Certificates, Identifiers
   & Profiles → Profiles → + → **App Store Connect**, choose the existing explicit
   identifier and REACH Distribution certificate, download to Files, then upload
   under Codemagic provisioning profiles. Confirm the certificate matches. Do not
   revoke or replace unrelated signing assets. TestFlight needs no device UDIDs.
3. Confirm Codemagic's **REACH Codemagic** integration can access the existing
   REACH Staging app and has the required App Manager permission. Keep its .p8,
   Key ID and Issuer ID in Codemagic; do not recreate the key unnecessarily.
4. Confirm the staging plist variable is available and set the next unused
   `REACH_IOS_BUILD_NUMBER`. Check version 0.1.0 in App Store Connect/TestFlight
   before choosing it. Resolve pending Apple agreements if the account reports
   them; do not configure paid agreements or billing.
5. Return these non-secret confirmations for review and approve a specific commit,
   build number and automatic upload. **Do not tap Start new build yet.**

After explicit approval, select branch **native-reach**, the reviewed commit and
workflow **REACH staging TestFlight (manual build, automatic upload)**. Starting
that workflow includes upload; it is no longer an archive-only dry run. There is
no need to start the simulator workflow separately: this workflow runs the native
simulator suite before archive. Inspect CI and Apple processing results before
claiming a signed build or install is verified. Tester invitations and beta review
remain separately approved actions. No developer-owned Mac is required.

## After an approved upload — invitations require separate approval

The owner completes any encryption/export-compliance answers based on the actual
SDKs and app behavior. Do not automatically answer legal attestations. Prepare beta
contact information and test notes explaining this is a foreground, consent-based
staging prototype. No background/overnight reliability is claimed.

- **Byron:** internal TestFlight tester through the existing App Store Connect user.
  Create a private internal group and manually assign the processed build.
- **Aaron:** prefer an email-only external tester invitation after the required
  TestFlight beta review. This avoids giving developer/account privileges merely
  to test. Internal testing is an option only if she independently needs an
  appropriate App Store Connect role and the owner approves it. Do not create a
  public invitation link or send invitations without explicit instructions.

Each person installs Apple's TestFlight from the App Store, accepts their private
invitation, verifies the REACH Staging version/build, and installs. Upload,
processing, beta review, invitation and actual installation are separate states;
none has occurred merely because an IPA exports successfully.

## Two-iPhone acceptance test (only after staging Auth approval)

Before live sign-in, obtain the owner's explicit approval to inspect/enable the
specific staging authentication provider if needed. Preserve existing Firebase
UIDs and all web pairing/member locks; never reset or reuse a web pairing record.

1. Confirm both builds display staging and have different native Firebase UIDs.
   Do not clear app data or reinstall an existing paired web app to obtain them.
2. A explicitly creates a fresh native invitation; B explicitly accepts it before
   expiry. Both reopen the app and verify the pairing persists.
3. A opens a hand; B deliberately takes it. Both deliberately grant camera and
   microphone access. Confirm actual moving video and intelligible sound in both
   directions. A simulator negotiation test is not a physical call.
4. Test mute/unmute, camera off/on, speaker/headphones and Bluetooth HFP. Confirm
   controls remain effective through delayed camera setup and reconnect attempts.
5. Test End from each phone, room expiration, revoke from each member and fresh
   re-pairing. Verify media stops, stale SDP/ICE is rejected and no automatic
   reconnection occurs after end/revocation/expiry.
6. Test Wi-Fi interruption, foreground/background and lock/unlock. Recovery must
   remain bounded by current consent and room expiry; otherwise require a fresh
   explicit connection. Do not promise uninterrupted background camera capture.
7. Repeat on different networks and cellular. Current transport is STUN/direct
   only. **No TURN relay is configured**, so NAT/firewall failures are a known
   blocker to claiming reliable cross-network calling. Any relay deployment,
   credentials, recurring cost or billing change needs separate approval.

Record commit/build, both device models/iOS versions, networks, time, consent
steps, observed audio/video and failure logs (no private SDP/ICE or keys in public
logs). Stop before any claim of a verified first call until both humans confirm it.

## Configuration validation for automatic upload

The workflow update passed the official Codemagic JSON schema downloaded from
https://codemagic.io/codemagic-schema.json, all workflow shell scripts passed
`bash -n`, and all **30 Python distribution/preparation tests passed** locally.
The simulator and ad-hoc workflow source is byte-for-byte unchanged. The branch
update uses `[skip ci]` to suppress automatic builds. No new build, signing
operation, upload, beta review, invitation or Firebase operation is performed.

Schema/local tests cannot verify private Codemagic credentials, profile presence,
API access, unused build numbers or Apple acceptance. The owner checks above are
still required; a successful signed macOS build remains unverified.

## CI evidence at preparation start

GitHub run 42234494340 at 1a3037e: portable Swift job passed; macOS job cancelled
with no steps. GitHub annotations state no hosted runner acquired the job and
macOS arm64 capacity constraints. The native CI job now uses the standard
macos-15-intel label; Codemagic remains Mac mini M2. This changes runner capacity,
not the physical-iPhone arm64 target or test requirements. New macOS results must
be reported from the actual run, not inferred from portable tests. Owner-reported
Codemagic build 11 on 1c60ac1 remains historical evidence only.

References checked November 6, 2026:
- https://docs.github.com/en/actions/reference/runners/github-hosted-runners
- https://docs.codemagic.io/yaml-code-signing/signing-ios/
- https://docs.codemagic.io/yaml-publishing/app-store-connect/
- https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api/
- https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/
- https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers/
- https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/
- https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype
