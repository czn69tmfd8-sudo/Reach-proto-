# REACH — upload-only procedure for the approved Adventure Book IPA

## Proven integration

The repository contains a previously used Codemagic integration:

- `integrations.app_store_connect: REACH Codemagic`
- Codemagic injects `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_KEY_IDENTIFIER`, and `APP_STORE_CONNECT_PRIVATE_KEY`.
- Historical upload script: `native/scripts/upload-build15.py`.
- Historical upload command: `app-store-connect publish --path <verified-existing-IPA> --enable-package-validation`.
- The historical `reach-ios-testflight-archive` workflow uses `publishing.app_store_connect.auth: integration` but it **builds an IPA**, and must NOT be used to upload this existing artifact.
- The historical Build 15 upload workflow also **builds and exports** and is pinned to a different source and number. Do NOT run it for Build 16.

## Exact authorized candidate

- Source: `c76561823ce4f48f3849c59a2efff327e5e78e59`
- Preparation branch: `release/adventure-book-archive-preparation`
- Archive-only workflow: `reach-adventure-approved-archive-only`
- Existing artifact: `REACH.ipa` (reported 15.05 MB) from the successful Build 16 archive-only Codemagic run
- Apple version/build: `0.1.0 (16)`
- Existing app: REACH Staging, `com.reachprototype.app`
- Apple team: `GFUK853ZT5`
- Staging Firebase: `reach-staging-a4745`
- Existing signing report: Apple Distribution, App Store provisioning, profile expiration 2027-11-06

## Strict upload-only procedure

1. **Confirm build 16 is unused immediately before upload.** Inspect App Store Connect > REACH Staging > TestFlight, including all build uploads and processing states. Stop if 16 is uploaded, processing, or reserved. This check cannot be inferred from the Codemagic archive's success.
2. **Retrieve the original existing IPA** from the successful archive-only Codemagic run. A subsequent workflow MUST retrieve the exact original artifact by authenticated Codemagic artifact download or use an explicit secure artifact transfer. A fresh checkout of the repository does not contain this IPA. Do not run `xcodebuild archive`, `xcodebuild -exportArchive`, or any rebuild step.
3. Record the original artifact's SHA-256 in the originating Codemagic run or from the downloaded IPA, and compare the uploaded input byte-for-byte (same SHA-256). File size and name alone do not prove identity.
4. Run the existing `native/scripts/prepare-store-export.py verify-ipa <directory>` on a macOS Codemagic machine with `REACH_APPLE_TEAM_ID=GFUK853ZT5` and `REACH_IOS_BUILD_NUMBER=16`. This validates the embedded version, signing, exact bundle, team, staging Firebase, icon, privacy manifest and camera/microphone descriptions.
5. Ensure the authenticated upload job has `integrations.app_store_connect: REACH Codemagic`. Fail closed if credentials are absent. Reuse the historical command `app-store-connect publish --path <exact-verified-existing-IPA> --enable-package-validation` with a sanitized environment as in `upload-build15.py`. Never pass an archive path, source checkout, or a different IPA.
6. Do not enable a Codemagic automatic publisher on any workflow that could build or collect another IPA. Do not assign testers or submit for beta review or public release.
7. After upload, verify version `0.1.0 (16)` under the **existing** REACH Staging application in App Store Connect. Record upload status separately from Apple processing status. Stop before tester distribution and obtain separate owner authorization.

## Current limitation / no implicit authorization to rebuild

The GitHub connector cannot access Codemagic's private artifacts, execute Codemagic builds, or inspect App Store Connect's live build list. A functional upload-only Codemagic workflow must first have a verified, authenticated way to retrieve the **same** IPA from the earlier Codemagic run. No such artifact-retrieval interface has yet been established in this repository. Do not invent a download URL, silently rebuild, or report an upload without the actual Apple response.

If Codemagic provides a durable authenticated artifact URL or the original IPA can be supplied to an authenticated upload job, add a separate, explicitly gated upload-only workflow. Do not change the already validated archive-only workflow.

## Dedicated upload-only workflow (November 11, 2026)

Prepared workflow: `reach-adventure-build16-upload-existing-ipa` on `release/adventure-book-archive-preparation`.

This workflow has **no xcodebuild, exportArchive, or publishing block**. It retrieves an IPA through Codemagic's documented `POST <artifact_url>/public-url` endpoint with `x-auth-token`, receives a short-lived download URL, downloads the original file, verifies a separately supplied original SHA-256, validates IPA identity/signature with existing repository checks, and uses the historical `app-store-connect publish` command. The temporary URL is intentionally never logged. Codemagic documents the three-step artifact retrieval at https://help.codemagic.io/articles/2191356328-how-do-i-download-build-artifacts-ipa-apk-using-the-codemagic-api .

Required **secure** Codemagic environment variables for this job (never commit their values):
- `CM_API_TOKEN`: authorized Codemagic API token capable of retrieving the original run's artifacts.
- `REACH_ORIGINAL_ARTIFACT_URL`: original artifact URL returned by `GET https://api.codemagic.io/builds/<original-build-id>` in `.build.artefacts[].url`, selecting the exact original `REACH.ipa`.
- `REACH_ORIGINAL_IPA_SHA256`: 64-character SHA-256 recorded independently from the **original** artifact, not calculated from a different file or a new build.
- `APP_STORE_APPLE_ID`: existing REACH Staging app's numeric Apple app ID (not the bundle identifier).
- `REACH_APPLE_UPLOADS_CLEAR=CONFIRMED_NO_BUILD_16_OR_HIGHER`: set only after checking App Store Connect's **live** build uploads, processing and reservations immediately before this run.
- Existing `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_KEY_IDENTIFIER`, `APP_STORE_CONNECT_PRIVATE_KEY` must be supplied by `REACH Codemagic` integration.
- Select workflow input `upload_approval=UPLOAD_EXISTING_BUILD_16_ONLY`; the default is HOLD.

The job also queries Apple's live latest build for version 0.1.0 with `app-store-connect get-latest-build-number --version-string=0.1.0`. This check does not guarantee visibility of all pending uploads/reservations, so the independent live App Store Connect uploads confirmation is mandatory.

**Important unresolved prerequisites:** No Codemagic API token, original artifact URL, independent original IPA SHA-256, or Apple numeric app ID has been verified available to this assistant. The upload-only workflow has not been executed or proven successful. Do not start it until these values are securely configured and the live Apple inventory has been confirmed. If the API fails, do not substitute a rebuilt IPA. No tester assignment is authorized.

After a successful upload command, the workflow emits `build-logs/build16-upload-result.json`. The JSON says upload command succeeded, **not** that Apple has finished processing. Inspect App Store Connect afterward; obtain separate authorization before any internal tester assignment.
