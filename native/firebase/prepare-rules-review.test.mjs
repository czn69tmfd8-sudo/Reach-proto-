import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile,mkdtemp,writeFile,rm} from 'node:fs/promises';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {buildAdditiveRules,prepareReview,readReview,sha256,stagingProject} from './prepare-rules-review.mjs';
const baseline=await readFile('fixtures/8956bb8-shared-collections.rules','utf8');
const native=await readFile('firestore.rules','utf8');
const options={project:stagingProject,expectedBaselineSHA:sha256(baseline)};
const build=(b,n=native,extra={})=>buildAdditiveRules(b,n,{...options,expectedBaselineSHA:sha256(b),...extra});
test('additive merge preserves every existing source byte and records pending approval hashes',()=>{
 const result=build(baseline);
 assert.equal(result.merged.replace(result.insertion,''),baseline);
 assert.match(result.insertion,/match \/nativeStaging\/v1/);
 assert.equal(result.manifest.deploymentApproved,false);assert.equal(result.manifest.liveBaselineVerified,false);
 assert.equal(result.manifest.mergedSHA256,sha256(result.merged));
});
test('comments strings and escaped braces do not corrupt insertion location',()=>{
 const b=baseline.replace('  function signed()',`  // } fake match /nativeStaging/v1 {\n  /* } */\n  function text() { return 'escaped \\' brace }'; }\n  function signed()`);
 assert.equal(build(b).merged.replace(build(b).insertion,''),b);
});
test('rejects truncated or unbalanced baselines and unterminated input',()=>{
 for(const b of [baseline.slice(0,-5),baseline+'}',baseline+"/*",baseline+"'"])assert.throws(()=>build(b));
});
test('rejects altered baseline hash or non-staging project',()=>{
 assert.throws(()=>build(baseline,native,{expectedBaselineSHA:'wrong'}),/SHA-256/);
 assert.throws(()=>build(baseline,native,{project:'reach-prototype-d70ef'}),/Only reach-staging/);
});
test('rejects existing native namespace and repeated merges',()=>{
 assert.throws(()=>build(build(baseline).merged),/already has/);
 assert.throws(()=>build(baseline.replace('match /rooms/{id}', 'match /nativeStaging/{id}')),/already has/);
});
test('rejects overlapping recursive grants even if caller is authenticated',()=>{
 const b=baseline.replace('  function signed()', '  match /{document=**} { allow read,write: if request.auth != null; }\n  function signed()');
 assert.throws(()=>build(b),/Broad dynamic-root grant/);
});
test('rejects dynamic root grants through functions rather than guessing their safety',()=>{
 const b=baseline.replace('  function signed()', '  match /{collection}/{document} { allow read: if signed(); }\n  function signed()');
 assert.throws(()=>build(b),/manual review/);
});
test('accepts explicit default deny alongside legacy matches',()=>{
 assert.doesNotThrow(()=>build(baseline.replace('  function signed()', '  match /{document=**} { allow read,write: if false; }\n  function signed()')));
});
test('rejects native candidates with grants outside native namespace',()=>{
 const n=native.replace('  match /nativeStaging/v1 {','  allow read: if true;\n  match /nativeStaging/v1 {');
 assert.throws(()=>build(baseline,n),/outside its block/);
});
test('writes a new review bundle without overwriting source or an existing review',async()=>{
 const root=await mkdtemp(join(tmpdir(),'reach-merge-test-'));
 try {
  const b=join(root,'deployed.rules'),n=join(root,'native.rules'),out=join(root,'review');
  await writeFile(b,baseline);await writeFile(n,native);
  const request={baselinePath:b,nativePath:n,outputDirectory:out,...options};
  const manifest=await prepareReview(request);
  assert.equal(await readFile(b,'utf8'),baseline);assert.equal(manifest.deploymentApproved,false);
  assert.equal(sha256(await readFile(join(out,'merged.rules'),'utf8')),manifest.mergedSHA256);
  await assert.rejects(prepareReview(request),/refusing overwrite/);
 } finally {await rm(root,{recursive:true,force:true})}
});

test('rejects grants on the documents root itself',()=>{
 assert.throws(()=>build(baseline.replace('  function signed()', '  allow read: if true;\n  function signed()')),/documents root/);
});

test('exact review source loads for emulator testing and rejects tampering',async()=>{
 const root=await mkdtemp(join(tmpdir(),'reach-exact-review-'));
 try {
  const b=join(root,'baseline.rules'),n=join(root,'native.rules'),out=join(root,'review');
  await writeFile(b,baseline);await writeFile(n,native);
  await prepareReview({baselinePath:b,nativePath:n,outputDirectory:out,...options});
  assert.equal(await readReview(out,native),build(baseline).merged);
  await writeFile(join(out,'merged.rules'),build(baseline).merged+'\n// altered');
  await assert.rejects(readReview(out,native),/artifact changed/);
 } finally {await rm(root,{recursive:true,force:true})}
});
