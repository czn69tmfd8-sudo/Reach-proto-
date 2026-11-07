import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {after,before,beforeEach,test} from 'node:test';
import {initializeTestEnvironment,assertSucceeds} from '@firebase/rules-unit-testing';
import {doc,getDoc,getDocs,collection,setDoc,updateDoc,deleteDoc,writeBatch,serverTimestamp} from 'firebase/firestore';
import {readReview,sha256} from './prepare-rules-review.mjs';
const review=process.env.REACH_RULES_REVIEW_DIR || 'reviews/staging-2026-11-06-hardened';
const root='nativeStaging/v1/',code='ABCDEFGHJKLM';let env;
const db=uid=>uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore();
const ref=(d,p)=>doc(d,root+p),candidate={candidate:'candidate:1',sdpMid:'0',sdpMLineIndex:0};
// A generic "evaluation error ... false" label alone does not identify a runtime error.
// Reject concrete missing-field/path/service-call and resource-limit diagnostics.
async function cleanDenied(operation) {
 await assert.rejects(operation,e=>{
  assert.equal(e.code,'permission-denied');
  assert.doesNotMatch(e.message,/null value error|undefined on object|service call error|invalid.argument|maximum.*(expression|call)/i);return true;
 });
}
async function admin(fn) {await env.withSecurityRulesDisabled(c=>fn(c.firestore()));}
async function seed() {
 await admin(async d=>{for(const [p,v] of Object.entries({
  ['pairInvites/'+code]:{hostUid:'a',partnerUid:'b',activeRoom:'r1',openedBy:'a',revoked:false,expiresAt:Date.now()+60000},
  'memberLocks/a':{pairCode:code},'memberLocks/b':{pairCode:code},
  'rooms/r1':{hostUid:'a',partnerUid:'b',pairCode:code,active:true,expiresAt:Date.now()+60000},
  'rooms/r1/hostCandidates/c1':candidate,'rooms/r1/partnerCandidates/c1':candidate
 }))await setDoc(ref(d,p),v);});
}
async function deny(uid,id='r1') {
 const d=db(uid);await cleanDenied(getDoc(ref(d,'rooms/'+id)));
 for(const side of ['hostCandidates','partnerCandidates']) {
  await cleanDenied(getDoc(ref(d,`rooms/${id}/${side}/c1`)));
  await cleanDenied(getDocs(collection(d,root+`rooms/${id}/${side}`)));
  await cleanDenied(setDoc(ref(d,`rooms/${id}/${side}/late`),candidate));
 }
}
before(async()=>{env=await initializeTestEnvironment({projectId:'demo-reach-lookup-guards',firestore:{rules:await readReview(review,await readFile('firestore.rules','utf8'))}});});
beforeEach(async()=>env.clearFirestore());after(async()=>env?.cleanup());
test('exact unauthenticated Playground probe denies without evaluation errors',async()=>{await cleanDenied(getDoc(ref(db(),'rooms/reach-readonly-probe')));});
test('missing rooms and orphan ICE deny cleanly for members outsiders and unauthenticated users',async()=>{
 await seed();await admin(d=>setDoc(ref(d,'rooms/missing/hostCandidates/c1'),candidate));
 for(const uid of [null,'a','b','outsider'])await deny(uid,'missing');
});
test('existing valid rooms and ICE deny cleanly without authentication or membership',async()=>{await seed();for(const uid of [null,'outsider'])await deny(uid);});
test('both members retain room and both ICE read directions',async()=>{
 await seed();for(const uid of ['a','b']) {
  const d=db(uid);await assertSucceeds(getDoc(ref(d,'rooms/r1')));
  for(const side of ['hostCandidates','partnerCandidates']) {
   await assertSucceeds(getDoc(ref(d,`rooms/r1/${side}/c1`)));
   assert.equal((await assertSucceeds(getDocs(collection(d,root+`rooms/r1/${side}`)))).size,1);
  }
 }
});
for(const [label,patch] of [
 ['empty',{}],['missing pairCode',{hostUid:'a',partnerUid:'b',active:true,expiresAt:1}],
 ['null pairCode',{pairCode:null}],['numeric pairCode',{pairCode:42}],['path pairCode',{pairCode:'wrong/path'}],
 ['invalid code',{pairCode:'WRONG'}],['malformed host',{hostUid:['a']}],['malformed partner',{partnerUid:'b/child'}],
 ['overlong UID',{hostUid:'a'.repeat(1501)}],['overlong UTF-8 UID',{partnerUid:'€'.repeat(501)}],
 ['reserved UID',{hostUid:'__reserved__'}],['dot UID',{partnerUid:'..'}],['malformed active',{active:'true'}],['malformed expiry',{expiresAt:'tomorrow'}]
])test(`malformed room: ${label} denies room and ICE cleanly`,async()=>{
 await seed();await admin(d=>setDoc(ref(d,'rooms/r1'),label==='empty'||label==='missing pairCode'?patch:{hostUid:'a',partnerUid:'b',pairCode:code,active:true,expiresAt:Date.now()+60000,...patch}));
 for(const uid of [null,'a','outsider'])await deny(uid);
});
test('missing pair and malformed identities deny without dependent lock lookups',async()=>{
 await seed();await admin(d=>deleteDoc(ref(d,'pairInvites/'+code)));await deny('a');
 for(const data of [{},{hostUid:'a',partnerUid:'b/child'},{hostUid:null,partnerUid:'b'},{hostUid:4,partnerUid:['b']}]) {
  await admin(d=>setDoc(ref(d,'pairInvites/'+code),data));await deny('a');
 }
});
test('missing malformed and mismatched locks deny cleanly',async()=>{
 await seed();await admin(d=>deleteDoc(ref(d,'memberLocks/b')));await deny('a');
 for(const data of [{},{pairCode:null},{pairCode:4},{pairCode:'wrong/path'},{pairCode:'MNPQRSTVWXYZ'}]) {
  await admin(d=>setDoc(ref(d,'memberLocks/b'),data));await deny('a');
 }
});
for(const [label,path,patch] of [
 ['revoked','pairInvites/'+code,{revoked:true}],['expired','rooms/r1',{expiresAt:0}],['ended','rooms/r1',{active:false}],
 ['stale pointer','pairInvites/'+code,{activeRoom:'other'}],['malformed opener','pairInvites/'+code,{openedBy:42}]
])test(`${label} denies both members room and ICE cleanly`,async()=>{await seed();await admin(d=>updateDoc(ref(d,path),patch));for(const uid of ['a','b'])await deny(uid);});
test('invalid create paths and missing after-state documents deny cleanly',async()=>{
 const d=db('a');for(const value of [null,42,'wrong/path','WRONG']) {
  await cleanDenied(setDoc(ref(d,'memberLocks/a'),{pairCode:value,createdAt:serverTimestamp()}));
  await cleanDenied(setDoc(ref(d,'rooms/new'),{pairCode:value,hostUid:'a',partnerUid:'b',active:true,createdAt:serverTimestamp(),expiresAt:Date.now()+60000}));
 }
 await cleanDenied(setDoc(ref(d,'memberLocks/a'),{pairCode:code,createdAt:serverTimestamp()}));
});
test('malformed active-room pointers never become getAfter paths',async()=>{
 await seed();await admin(d=>updateDoc(ref(d,'pairInvites/'+code),{activeRoom:null,openedBy:null}));
 for(const value of [42,'wrong/path','',null])await cleanDenied(updateDoc(ref(db('a'),'pairInvites/'+code),{activeRoom:value,openedBy:'a'}));
});
test('malformed previous locks deny fresh pairing without lookup errors',async()=>{
 const d=db('a');for(const data of [{},{pairCode:null},{pairCode:42},{pairCode:'wrong/path'},{pairCode:'MNPQRSTVWXYZ'}]) {
  await admin(w=>setDoc(ref(w,'memberLocks/a'),data));const b=writeBatch(d);
  b.set(ref(d,'pairInvites/'+code),{hostUid:'a',partnerUid:null,activeRoom:null,openedBy:null,createdAt:serverTimestamp(),expiresAt:Date.now()+60000});
  b.set(ref(d,'memberLocks/a'),{pairCode:code,createdAt:serverTimestamp()});await cleanDenied(b.commit());
 }
});
test('web source is byte-identical and replacement is confined to the native insertion',async()=>{
 const [baseline,merged,insertion,published,oldInsertion]=await Promise.all([
  readFile(review+'/baseline.rules','utf8'),readFile(review+'/merged.rules','utf8'),readFile(review+'/native-addition.rules','utf8'),
  readFile('reviews/staging-2026-11-06-fresh/merged.rules','utf8'),readFile('reviews/staging-2026-11-06-fresh/native-addition.rules','utf8')]);
 assert.equal(sha256(published),'d23ac0d8a31496a10ac0fff6e3d439daf3951d3246ec74154d6e956ef0f7e70a');
 assert.equal(merged.replace(insertion,''),baseline);assert.equal(published.replace(oldInsertion,''),baseline);
});

test('malformed SDP descriptions deny without field evaluation errors',async()=>{
 await seed();for(const value of [null,{},'offer',{type:'offer'},{sdp:'v=0'}])await cleanDenied(updateDoc(ref(db('a'),'rooms/r1'),{offer:value}));
});
test('missing pair room-state fields deny room creation cleanly',async()=>{
 await seed();await admin(d=>setDoc(ref(d,'pairInvites/'+code),{hostUid:'a',partnerUid:'b',revoked:false}));
 const d=db('a'),b=writeBatch(d);b.set(ref(d,'rooms/new'),{hostUid:'a',partnerUid:'b',pairCode:code,active:true,createdAt:serverTimestamp(),expiresAt:Date.now()+60000});
 b.update(ref(d,'pairInvites/'+code),{activeRoom:'new',openedBy:'a'});await cleanDenied(b.commit());
});
