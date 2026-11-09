# Read-only Firebase staging verification

The manual Codemagic workflow `reach-staging-firestore-verify` targets only
`reach-staging-a4745`, Firestore `(default)`. The existing iOS client plist
and Apple integration do not authorize Rules API reads. Check Codemagic's app
settings for an already approved dedicated rules-reader credential by its name
and IAM assignment. Keep the credential value private.

## One-time setup in Safari

These are owner/admin actions and require approval for any new IAM binding or
key. On iPhone, use Safari's **Request Desktop Website** if the consoles hide
their controls.

1. Open [Google Cloud IAM](https://console.cloud.google.com/iam-admin/roles?project=reach-staging-a4745)
   and confirm the selected project is exactly `reach-staging-a4745`. Confirm the existing service account has the `Firebase Rules Viewer` role
   on this staging project. Do not change existing IAM roles unless reviewed.
2. Under **Service Accounts**, select or, once approved, create
   `reach-staging-rules-reader@reach-staging-a4745.iam.gserviceaccount.com`. Grant the
   custom role on this staging project only. Ensure this identity has no other
   project, folder, organization, Firestore data, or deployment grants. Do not
   reuse a Firebase Admin SDK, deployer, personal login, or production key.
3. If a matching approved key is already available, use it. Otherwise, only
   after approval, open that service account's **Keys > Add key > Create new
   key > JSON**. If key creation is blocked by policy, stop and use the
   organization's approved credential path. The workflow does not change any
   project settings. If the Rules API is unavailable, stop and report it.
4. In Codemagic, open the REACH app's **Settings > Environment variables**.
   Create the app-level group `reach-staging-rules-readonly`. Add
   `REACH_STAGING_RULES_READER_JSON` as **Secret**. Open the downloaded JSON in
   Files and copy the complete text directly into that field. Keep the JSON out
   of chat, GitHub, other workflows, and screenshots. Keep the group app-only
   and run trusted repository code only.
5. Verify that access to this Codemagic app is restricted to authorized release
   staff. Keep **Build dashboards** public sharing disabled and check that there
   are no public artifact links or artifact-sharing notifications. Review the
   account's artifact retention window and record it for the release. Only then
   add `REACH_RULES_PRIVATE_ARTIFACTS_CONFIRMED=yes` to the same group. This
   variable is an operator attestation, not an automated check of team settings.
   If the settings or retention are unacceptable, leave it unset.

## Run and interpret the result

1. In Codemagic, select **Start new build**, branch `native-reach`, and workflow
   `reach-staging-firestore-verify` (REACH staging Firestore rules verification).
   Select the reviewed workflow commit. This workflow has no automatic trigger
   or publisher.
2. Open the step log for the release resource name, referenced ruleset ID,
   update time, hashes and outcome. Download `active.rules` and
   `verification.json` only from the signed-in build's **Artifacts** section.
   The source is the UTF-8 byte sequence returned by the Rules API, with its
   original whitespace and trailing newline, if present. Never generate a
   public share link. Codemagic applies account-level retention. Keep a copy in
   approved restricted storage if needed beyond that window. For a one-time
   key, revoke it in Google Cloud and remove the Codemagic variable after use.
3. Treat a failed or missing verification as a release hold. A changed active
   hash produces a failed job and a snapshot for private review when Codemagic
   collects artifacts from the failed run. A changed candidate hash stops the
   job before it accesses Firebase. The verifier re-reads the release pointer
   after fetching the ruleset and stops if it moved during the read.
4. A green run clears the baseline-check gate only. Record the build ID and
   report in the release review. Recheck before any separately approved
   publication. Keep the remaining pilot-flag, editor readback, approval and
   smoke-test gates in the [staging plan](firebase/reviews/staging-relationship-space/PLAN.md).
   The existing iOS archive workflows remain independent. This release hold is
   enforced by the verifier's failing status and the release review, not by an
   automatic dependency added to Build 5 or Build 6.

References: [Rules API](https://firebase.google.com/docs/reference/rules/rest),
[Codemagic secrets](https://docs.codemagic.io/yaml-basic-configuration/configuring-environment-variables/),
[artifact access](https://docs.codemagic.io/rest-api/artifacts/),
[retention](https://docs.codemagic.io/billing/pricing/).
