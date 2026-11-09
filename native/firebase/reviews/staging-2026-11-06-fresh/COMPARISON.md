# Fresh console-copy review — local preparation only

Target: reach-staging-a4745, (default) database. User-reported and screenshot-visible
published version: October 17, 2026, 2:17 PM (displayed timezone not established).
Source: the complete fresh rules pasted by the owner in this Work thread alongside
IMG_6112.png and IMG_6113.png. This is not an authenticated API download by the agent.
The previously approved single final LF normalization is retained in the saved copy.

## Findings

The complete fresh copy differs from the baseline at 78a568c only by **13 inserted
empty LF lines**. Every nonblank line is byte-identical, including indentation,
comments, literals, predicates and limits. All insertions separate declarations or
blocks; none alters a string or comment boundary. No security behavior changed.
The original 820-line baseline has 21,971 bytes; this 833-line copy has 21,984 bytes.

The unchanged published-version label is consistent with copying/formatting drift
between the supplied copies. The screenshots do not show the entire editor or its
original source bytes, so they cannot establish whether the additional empty lines
were present in Firebase or introduced by an earlier/later copy. No live-policy
change is evidenced. Do not represent this provenance uncertainty as a policy defect.

| Original insertion line | Fresh line containing inserted empty line |
| --- | --- |
| 61 | 61 |
| 108 | 109 |
| 253 | 255 |
| 278 | 281 |
| 307 | 311 |
| 320 | 325 |
| 335 | 341 |
| 349 | 356 |
| 385 | 393 |
| 425 | 434 |
| 426 | 436 |
| 809 | 820 |
| 811 | 823 |

## Artifact decision

The original merged.rules remains valid in security behavior; whitespace provides
no functional reason to replace it. However, it does not preserve every byte of the
fresh supplied copy. This revised candidate preserves the full fresh baseline,
including all 13 empty lines, and adds the exact unchanged nativeStaging/v1 block.
Use this candidate for a workflow requiring literal fresh-source preservation.
Do not silently substitute this new checksum under approval naming the old checksum.

No existing review, fixture, test source, native application code or CI workflow was
changed. The old review bundle remains intact. As in the original generated artifact,
git diff --check flags a two-space blank line at the insertion boundary (revised line
832). It is retained from the unchanged merge construction rather than silently
rewriting the preserved source prefix; it has no security-rule effect.

## Verified files

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| baseline.rules | 21984 | `437d87ced527f053b807ba7744fc61bb74ed3a3f0e2c93e2aa61a9ca386ef86e` |
| merged.rules | 29813 | `d23ac0d8a31496a10ac0fff6e3d439daf3951d3246ec74154d6e956ef0f7e70a` |
| native-addition.rules | 7829 | `5e55ec82952545ea214fc7c5856a01d3ab1dc5e7b388af9e6f082989b65ee047` |

Revised merged.rules: **929 lines, 29,813 bytes**. Removing its one recorded native
insertion reproduces the fresh baseline byte-for-byte. The native-only source and
insertion match the original approved versions exactly. The original merged checksum
remains e79d68ef918dc822a16d43af9be1106fa818d4d729cdd0b01ff94343890503fb.

## Security validation

All **69 cases passed**, zero failures/skips/cancellations, in the local Firestore
emulator using demo project IDs. They cover 18 web before/after cases, 27 native
security cases, 12 historical regressions and 12 merge/integrity checks.

An isolated test workspace used the fresh baseline as the deployed-web fixture and
the exact revised review through REACH_RULES_REVIEW_DIR. Only the two expected fixture
checksum literals were updated in that temporary workspace to pin the new baseline;
all policy assertions/cases were retained. The repository tests and historical fixtures
were not edited, bypassed or weakened. readReview reconstructed and hash-checked the
exact candidate before loading it. Web compatibility ran against the fresh baseline
before and the revised merged rules after insertion.

## Publication and rollback status

No Firebase console interaction, authenticated API access, deployment, authentication
change, production access, data write or billing change occurred. No GitHub push or CI
rerun is part of this local preparation. Deployment is NOT approved for this new file.
review.json deliberately retains deploymentApproved=false and liveBaselineVerified=false;
the live source is owner-attested, not independently downloaded by this agent.

If this candidate is later explicitly approved, verify project/database and published
source/version again, paste/read back the entire candidate, and verify the checksum
before a separate publication decision. For rollback use this bundle's baseline.rules,
which preserves the fresh spacing. Check for intervening edits before restoring it.
Restoring that baseline denies the native namespace again without deleting records.
No publication or rollback is authorized or executed by this report.
