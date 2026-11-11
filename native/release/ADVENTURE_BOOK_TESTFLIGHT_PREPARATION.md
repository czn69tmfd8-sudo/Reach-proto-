# REACH Staging — Adventure Book Update

## Release candidate
- Application: Existing REACH Staging (no new app)
- Bundle identifier: `com.reachprototype.app`
- Firebase staging: `reach-staging-a4745`
- Apple Team: `GFUK853ZT5`
- Version: `0.1.0`
- Proposed Apple build: `8` — **HOLD until App Store Connect confirms unused**
- Validated application source: `c76561823ce4f48f3849c59a2efff327e5e78e59`
- CI validation: https://github.com/czn69tmfd8-sudo/Reach-proto-/actions/runs/43067005905
- Preparation branch: `release/adventure-book-archive-preparation`

## Internal TestFlight release notes

**REACH Staging — Adventure Book Update**

Introduces our new leather-bound Adventure Book within the Us section, featuring scrapbook-style memory browsing, individual story pages and shared reflections.

Existing calling and pairing functionality is retained.

Photo uploads remain disabled pending secure storage activation.

## Distribution hold
- Do not upload to App Store Connect or distribute through TestFlight without new authorization.
- Do not merge into the release branch.
- Do not modify Firebase rules, Storage permissions, authentication, pairing or calling.
- Do not change the approved Adventure Book design.
- Run only the `reach-adventure-approved-archive-only` Codemagic workflow after confirming build 8 is unused.
- If build 8 is already used, stop and revise the release workflow to the next confirmed unused number **before** starting any archive.
- The existing historical Build 15 workflow is not suitable for this release and must not be selected.

## Required evidence before upload approval
1. App Store Connect screenshot or verified build inventory showing selected number is unused.
2. Codemagic archive-only run success and signed IPA artifact.
3. Signed archive and IPA verification, including provisioning, entitlements, Firebase staging identity, app icon and privacy manifest.
4. Confirm exact commit, version and build in the exported artifact.
5. Obtain explicit owner authorization for upload and subsequent internal distribution.
