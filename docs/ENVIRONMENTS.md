# Environment inventory

| Role | Published entry | Firebase project | UI assets |
| --- | --- | --- | --- |
| Production | `index.html` | `reach-prototype-d70ef` | `production-assets/` (proposed, not deployed) |
| Testing | `staging/index.html` | `reach-staging-a4745` | `staging/` |

Current live `main` still imports `staging/reach2-*.js` in production. This branch changes that dependency without changing app logic. Do not merge until the owner validates staging and approves deployment.

## Known limitations
- The staging branch is not the published `/staging/` path by default.
- Production device migration has reported permission-denied; unresolved.
- Kitchen recipe storage is local-only and the fifth Together tile has a handler collision in the feature layer.
- The shared daily question uses a Firebase adapter; other feature data may remain local.
- GitHub Pages source/settings and deployed commit still require direct verification.
