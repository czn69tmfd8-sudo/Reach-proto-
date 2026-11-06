# Installing the staging prototype on two iPhones

## Current verification

Codemagic build **11** on `1c60ac1` is owner-confirmed successful, following
build **10** on `0a87493` shown in the supplied screenshots: simulator build,
installation, launch, native test step, and unsigned physical-iPhone compilation. These reports do not establish an exact build #11 simulator
test count or any physical-device runtime result. Local portable tests are
reported separately and do not replace the Xcode SDK tests.

The owner confirms Apple Developer membership is now active through November 6,
2027 and App Store Connect access is granted. Follow [TESTFLIGHT.md](TESTFLIGHT.md)
for current iPhone-only signing, private distribution and two-phone acceptance
steps. The owner manually published the hardened staging rules at 10:02 AM on
November 6; the supplied complete source matched the approved 7e62b5e9 checksum.
Firebase Authentication remains paused. Live native SDK sign-in, two-device
pairing and media delivery remain unverified.

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

1. The Team ID from the owner's now-active Apple Developer Program membership. Do not enroll/pay again or automatically. A free personal
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

## TestFlight preparation and live test gate

See [TESTFLIGHT.md](TESTFLIGHT.md) for the manual App Store-signed archive workflow,
secure Codemagic signing setup and the separate upload/invitation approval gate.
The archive workflow does not upload or publish. No signed IPA has yet been
verified. TestFlight does not need device UDIDs; the older ad-hoc route above does.

The published rules review is `firebase/reviews/staging-2026-11-06-hardened/`.
Authentication remains paused until separately approved. Once installed and
explicitly authorized for staging sign-in, use fresh native pairings and deliberate
camera/microphone consent. Exercise End, expiry, revocation, re-pair and recovery
before claiming success. Do not migrate or reset existing web pairing data.
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
