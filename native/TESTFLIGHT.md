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

`reach-ios-testflight-archive` in `codemagic.yaml` is **manual, archive/export only**.
It requires an existing App Store distribution certificate/private key and exact
bundle provisioning profile in Codemagic. It does not create signing resources,
contact App Store Connect, upload a build, distribute to testers or submit to review.
There is no publishing block or automatic trigger. The existing ad-hoc workflow
continues to require registered-device signing; its verifier still rejects store
profiles in ad-hoc mode.

Before starting the workflow, set these variables in the existing protected
`reach-staging` Codemagic group:

| Variable | Value |
| --- | --- |
| REACH_STAGING_FIREBASE_PLIST_BASE64 | Existing staging iOS client configuration for this exact project and bundle; required, never printed |
| REACH_APPLE_TEAM_ID | Actual 10-character Team ID from Apple Developer Membership Details |
| REACH_IOS_BUILD_NUMBER | Next unused integer, 1–9999, for version 0.1.0 in App Store Connect |

Team ID and build number are not signing secrets. Never paste API private keys,
.p12 passwords, full signing files or credentials into chat or GitHub.
No new Firebase iOS app/configuration should be registered without inspecting the
existing staging registration. If the required plist is missing, stop for account
access; never substitute production configuration.

The workflow validates inputs and Python checks, generates the Xcode project,
runs native simulator tests, applies existing App Store profiles, archives for
physical iPhone, verifies staging bundle/project and the expected signing team,
then exports locally. The export verifier rejects upload destinations and other
bundle profiles. The exported IPA is unpacked and checked again, including its
signature/profile, build number, icon, privacy manifest and camera/mic descriptions.
Artifact export is not proof Apple has accepted/processed the IPA.

The icon reuses the existing web heart geometry on an opaque background; it is
staging packaging, not a final branding decision. The app privacy manifest declares
its observed own-app UserDefaults access (`CA92.1`). This declaration does not
replace the separate SDK privacy manifests, App Store privacy disclosures or
export-compliance answers. Those must be reviewed before upload. Encryption uses
Firebase/WebRTC; no `ITSAppUsesNonExemptEncryption=false` declaration is guessed.

## iPhone-only owner setup (Safari; Request Desktop Website if needed)

1. Open https://developer.apple.com/account/ and Membership Details. Record the
   **Team ID**. Check the correct developer team is selected.
2. In Certificates, Identifiers & Profiles → Identifiers, find the explicit iOS
   App ID **com.reachprototype.app**. If absent, register that exact identifier,
   description **REACH Staging**, with only capabilities the app actually needs.
   No push, iCloud, Sign in with Apple or associated domains are required by the
   current prototype. If the identifier is unavailable, stop; do not change it.
3. Open https://appstoreconnect.apple.com/ → Apps → + → New App, if no record exists.
   Platform iOS; name **REACH Staging** (if unavailable, choose a name with the
   owner); primary language English (Canada) if available; bundle ID
   **com.reachprototype.app**; SKU **reach-native-staging-1**. Choose Limited Access
   where offered. Creating a private app record does not publish the app. Record
   the numeric Apple ID in App Information. Do not configure paid agreements,
   pricing, subscriptions or public release.
4. In App Store Connect → Users and Access → Integrations → App Store Connect API,
   if Request Access appears, the **Account Holder** must review and submit that
   request. Account access is not the same as API access. Once available, an
   Account Holder/Admin can create a dedicated team key named **REACH Codemagic**,
   with App Manager access. A team key applies across the account's apps; Apple
   does not restrict it to this one app. Approve that access deliberately. If
   permissions are insufficient for signing, stop rather than silently granting
   Admin. Download the .p8 once to Files and retain its Issuer ID and Key ID.
5. In Codemagic Team settings → Team integrations → Developer Portal → Manage keys,
   add the key using the .p8 from Files plus Issuer ID and Key ID. Store it directly
   there, not in this repository or conversation. No Apple password is needed in
   the workflow. Codemagic team-admin access is required for signing identities.
6. In Codemagic → Team settings → codemagic.yaml settings → Code signing identities
   → iOS certificates, use an existing valid **Apple Distribution** certificate
   and its private key, or Generate certificate using the integration. Retain
   the generated certificate/password securely and follow the UI's upload step.
   If Apple's certificate limit is reached, stop; do not revoke another certificate.
7. In Apple Developer → Profiles → +, create an **App Store Connect** distribution
   profile for com.reachprototype.app and that Apple Distribution certificate.
   Download to Files; upload it under Codemagic iOS provisioning profiles (or fetch
   the existing matching profile). Confirm Codemagic shows a matching certificate.
   **TestFlight needs no device UDIDs or Developer Mode.** Ad-hoc distribution is a
   different route and still needs UDIDs.
8. Set the variables above. Run `reach-ios-simulator` on the intended native-reach
   commit first. When validation passes, manually run
   **REACH staging TestFlight archive (manual, upload disabled)** on that same
   commit. Download/retain the IPA and build logs privately. Do not start any
   upload or distribution until the owner gives that separate approval.

No developer-owned Mac is required for this cloud workflow. Account-holder actions
that cannot be delegated include the initial API access request and any required
Apple agreement acceptance. App records and team API keys also require appropriate
roles; normal App Store Connect access alone may not be sufficient.

## Upload and invitations — separate approval required

After a signed archive/export passes, inspect its exact commit, build number,
staging config/signature evidence and complete CI results with the owner.
Only then configure an authorized Codemagic App Store Connect upload, with public
App Store submission explicitly disabled. Do not upload a .ipa in Files to a public
file-sharing or hosting service. Normal TestFlight requires an App Store Connect
upload/processing step; an ad-hoc IPA cannot substitute for it.

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
