import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {test} from 'node:test';
import {buildRelationshipReview, readRelationshipReview, relationshipReview, sha256} from './prepare-rules-review.mjs';

const baseline = await readFile(new URL('./reviews/staging-2026-11-06-hardened/merged.rules', import.meta.url), 'utf8');
const proposal = await readFile(new URL('../sync-proposal/relationship-space.proposed.rules', import.meta.url), 'utf8');

test('exact sharing candidate consists of a single removable insertion', async () => {
 const {insertion,manifest} = await relationshipReview();
 const merged = await readRelationshipReview();
 assert.equal(merged.split(insertion).length, 2);
 assert.equal(merged.replace(insertion,''), baseline);
 assert.equal(sha256(merged),manifest.mergedSHA256);
 assert.equal(manifest.project,'reach-staging-a4745');
 assert.equal(manifest.database,'(default)');
 assert.equal(manifest.deploymentApproved,false);
 assert.equal(manifest.liveBaselineVerified,false);
});

test('merge refuses a changed baseline, overlapping match and root allow', () => {
 assert.throws(() => buildRelationshipReview(baseline + '\n',proposal), /reference changed/);
 assert.throws(() => buildRelationshipReview(baseline,proposal.replace('match /nativeStaging/v1/relationshipSpace/', 'match /nativeStaging/v1/rooms/')), /isolated/);
 assert.throws(() => buildRelationshipReview(baseline,proposal.replace('function spacePairPath', 'allow read: if true; function spacePairPath')), /Unexpected code/);
 assert.throws(() => buildRelationshipReview(baseline,proposal.replace('spacePairPath','pairPath')), /helper/);
});
