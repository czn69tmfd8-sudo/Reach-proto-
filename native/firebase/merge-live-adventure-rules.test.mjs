import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,readFile,writeFile,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {spawnSync} from 'node:child_process';
const firestore = "rules_version = '2';\nservice cloud.firestore { match /databases/{database}/documents {\nmatch /legacy/{id} { allow read: if request.auth != null; allow write: if false; }\nmatch /nativeStaging/{id} { allow read: if false; }\n// pairInvites memberLocks\n}\n}\n";
const storage = "rules_version = '2';\nservice firebase.storage { match /b/{bucket}/o {\nmatch /existing/{id} { allow read: if request.auth != null; allow write: if false; }\n}\n}\n";
test('offline merge retains existing Storage and Firestore rules byte-for-byte and appends additions',async()=>{
 const dir=await mkdtemp(join(tmpdir(),'reach-merge-'));
 try {
  const fs=join(dir,'live.firestore.rules'),st=join(dir,'live.storage.rules'),out=join(dir,'merged');
  await writeFile(fs,firestore);await writeFile(st,storage);
  const run=spawnSync(process.execPath,['merge-live-adventure-rules.mjs',fs,st,out],{encoding:'utf8'});
  assert.equal(run.status,0,run.stderr);
  const mergedFs=await readFile(out+'.firestore.rules','utf8');
  const mergedSt=await readFile(out+'.storage.rules','utf8');
  assert.ok(mergedFs.includes("match /legacy/{id} { allow read: if request.auth != null; allow write: if false; }"));
  assert.ok(mergedSt.includes("match /existing/{id} { allow read: if request.auth != null; allow write: if false; }"));
  assert.ok(mergedSt.includes('match /adventureBook/{code}/{memoryID}/{photoID}'));
  assert.ok(mergedFs.includes('match /adventureBooks/{code}/memories/{memoryID}'));
  assert.equal((mergedSt.match(/service firebase.storage/g)||[]).length,1);
  assert.equal((mergedFs.match(/service cloud.firestore/g)||[]).length,1);
  const manifest=JSON.parse(await readFile(out+'.manifest.json','utf8'));
  assert.equal(manifest.deployAuthorized,false);
  assert.ok(manifest.sha256.liveStorage && manifest.sha256.mergedStorage);
  // Re-merging must fail closed rather than introducing duplicate matches.
  const second=spawnSync(process.execPath,['merge-live-adventure-rules.mjs',out+'.firestore.rules',out+'.storage.rules',out+'2'],{encoding:'utf8'});
  assert.notEqual(second.status,0);
 } finally {await rm(dir,{recursive:true,force:true});}
});
test('merge refuses missing native staging protections',async()=>{
 const dir=await mkdtemp(join(tmpdir(),'reach-merge-'));
 try {
  const fs=join(dir,'f.rules'),st=join(dir,'s.rules');
  await writeFile(fs,firestore.replace('pairInvites memberLocks','missing protections'));
  await writeFile(st,storage);
  const run=spawnSync(process.execPath,['merge-live-adventure-rules.mjs',fs,st,join(dir,'out')],{encoding:'utf8'});
  assert.notEqual(run.status,0);
 }finally{await rm(dir,{recursive:true,force:true});}
});
