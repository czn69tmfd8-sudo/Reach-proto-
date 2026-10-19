# REACH development and release workflow

## Environments
- Production: GitHub Pages `/Reach-proto-/`, root `index.html` on `main`, Firebase `reach-prototype-d70ef`.
- Staging: GitHub Pages `/Reach-proto-/staging/`, `staging/index.html` on `main`, Firebase `reach-staging-a4745`.
- The GitHub branch named `staging` is NOT the currently verified publishing source for the staging URL. Do not assume committing to it deploys the staging site.
- Feature branches: `feature/<name>` or `fix/<name>`, created from `main`. Feature branches are not automatically deployed.

## Rules
1. Never edit production root or `production-assets/` while testing features. No direct pushes to `main` for unreviewed work.
2. Develop changes in a feature branch; inspect diffs and security effects.
3. Promote approved feature changes to the `staging/` directory on the publishing branch via reviewed PR. Verify the actual GitHub Pages deployment, not just a successful commit.
4. Test on both iPhones with staging Firebase, including pairing, call setup/teardown, reload, and permissions. Record results.
5. Explicit owner approval is required to promote a tested change to production. Deploy only approved files; do not copy the entire staging app into production.
6. After deployment, smoke-test production and record the release commit. Revert the release commit on failure.
7. Never share Firebase credentials, migration tokens, or partner IDs in screenshots, issues, or logs. Never weaken Firestore rules to pass a test.

## Current stabilization release
- Isolate production UI assets from `staging/` (in progress, feature branch).
- Repair Kitchen tile handler on staging.
- Inspect Firebase migration permission failures; no rules changes without audit.
- Add smoke checks and release record.

## Release checklist
- [ ] Diff reviewed, no production credentials exposed
- [ ] Production and staging asset imports independent
- [ ] Staging deployment confirmed at actual URL
- [ ] Both devices: pairing, video connect/disconnect, reload
- [ ] Feature-specific behavior and persistence
- [ ] Firestore authorization tests where relevant
- [ ] No console errors or broken navigation
- [ ] Owner approves production promotion
- [ ] Production smoke test and rollback commit recorded
