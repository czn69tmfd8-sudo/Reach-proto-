# Installing the staging prototype on two iPhones

## Current verification

Codemagic build **11** on `1c60ac1` is owner-confirmed successful, following
build **10** on `0a87493` shown in the supplied screenshots: simulator build,
installation, launch, native test step, and unsigned physical-iPhone compilation. These reports do not establish an exact build #11 simulator
test count or any physical-device runtime result. Local portable tests are
reported separately and do not replace the Xcode SDK tests.

Live REST anonymous sign-in, token-backed lookup, and deletion of the newly
created staging test account were previously verified. Native Firebase SDK
sign-in, live two-device pairing, and media delivery remain unverified.
The approved additive rules have not been deployed: the browser's Google sign-in
expired before authorization completed. A fresh authenticated session must read
and compare the live baseline before the existing deployment approval can be used.

## Prepared workflows

- `reach-ios-simulator`: automatic native branch validation. It also compiles the
  physical-iPhone source branch without signing credentials, catching code hidden
  by simulator conditionals. The unsigned device compile passed in builds 10 and 11; later changes still need CI validation.
- `reach-ios-device`: **manual**, using existing ad-hoc identities in Codemagic.
  It requires staging config, archives Release for iPhone hardware, verifies bundle,
  project, platform and signature, and exports an IPA artifact. It has no automatic
  trigger, TestFlight upload, publishing block, or Firebase deployment command.
  No installable IPA has yet been generated or verified.

## What the owner must supply for registered-device installation

1. Activation of the owner's already purchased Apple Developer Program membership,
   then its Team ID. Do not enroll/pay again or automatically. A free personal
   account plus local simulator
   ad-hoc signing is not the configured cloud distribution route.
2. An explicit App ID owned by that team for `com.reachprototype.app`.
   If unavailable under that team, stop for a bundle-ID decision; changing it
   also needs a matching staging Firebase iOS app/configuration.
3. Register Byron's and Aaron's iPhone UDIDs in that developer team.
4. An Apple Distribution signing certificate **with its private key**, exported
   as a password-protected `.p12`, and an ad-hoc `.mobileprovision` profile for
   this bundle that includes both registered devices and that certificate.
5. Upload those signing identities to Codemagic's protected Code signing
   identities settings. Do not send private keys/passwords in chat or GitHub.
   `ios_signing` selects the matching ad-hoc profile/certificate; `use-profiles`
   applies them only to the generated project in the build workspace.

Apple lists Account Holder or Admin as the role for creating the ad-hoc profile.
With existing uploaded signing files, this IPA workflow does not need an App Store
Connect API key or a Mac owned by the user. Alternatively, the owner can configure
Codemagic's Apple integration to manage signing; that access must be approved and
established in Codemagic, not embedded in this repository.

## Additional requirements for TestFlight later

- An App Store Connect app record for the owned bundle ID, and its numeric Apple ID.
- App Store distribution signing/profile and a separate store-export workflow.
  An ad-hoc IPA cannot be substituted for a TestFlight build.
- An App Store Connect integration with an appropriately scoped upload role
  (for example App Manager), Key ID, Issuer ID, and `.p8` key stored in Codemagic.
  Automatic certificate/profile creation may require broader signing permissions;
  manually supplied signing files avoid granting those merely for uploading.
- The owner handles any outstanding Apple agreements and app encryption/export
  compliance answers. No legal attestation is auto-filled here.
- Internal testing is for App Store Connect users with suitable roles. Aaron can
  instead be an external beta tester, avoiding developer-team access just to test;
  external beta review/test information is then required.

No TestFlight upload or App Store submission is configured or authorized by this
preparation. The owner must explicitly approve the eventual upload/distribution.

## Live two-device test gate

The complete staging rules were supplied by the owner on November 5. The additive
artifact and before/after compatibility tests are in
`firebase/reviews/staging-2026-11-05/`. The owner approved that exact tested artifact
for `reach-staging-a4745`, then
paused authentication and deployment. Keep both paused. Before using the existing
approval after the pause is lifted, verify the live baseline and artifact hashes
match the approved review; stop on any difference. Then use fresh **native**
pairings on the two installed phones, grant camera/microphone intentionally, and
verify sound and moving video in both directions. Exercise End, backgrounding,
revocation, re-pairing and expiration. No overnight auto-join is enabled.
Direct/STUN connectivity is implemented; no TURN relay has been provisioned, so
separate/cellular network reliability remains unverified.

## Primary references

- Apple ad-hoc profile requirements and owner roles:
  https://developer.apple.com/help/account/provisioning-profiles/create-an-ad-hoc-provisioning-profile/
- Codemagic signing identity storage and workflow selection:
  https://docs.codemagic.io/yaml-code-signing/signing-ios/
- Apple internal TestFlight testers:
  https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers
- Apple external TestFlight information:
  https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information/
