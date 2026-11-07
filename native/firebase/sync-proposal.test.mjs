// Emulator-only tests of the NON-DEPLOYED shared-content proposal.
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {before, beforeEach, after, test} from 'node:test';
import {initializeTestEnvironment, assertSucceeds, assertFails} from '@firebase/rules-unit-testing';
import {doc, collection, getDoc, getDocs, setDoc, updateDoc, deleteDoc, serverTimestamp, Timestamp} from 'firebase/firestore';
let env;
const code='ABCDEFGHJKLM';
const path=`nativeStaging/v1/coupleContent/${code}/items`;
const pairPath=`nativeStaging/v1/pairInvites/${code}`;
const db=uid=>uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore();
const entry=(uid='a', patch={})=>({kind:'memory',authorUid:uid,title:'A moment',text:'Private until chosen',eventAt:Timestamp.now(),category:'',status:'saved',questionId:null,createdAt:serverTimestamp(),updatedAt:serverTimestamp(),consentedAt:serverTimestamp(),...patch});
async function admin(path,data) { await env.withSecurityRulesDisabled(c=>setDoc(doc(c.firestore(),path),data)); }
before(async()=>{
 assert.match(process.env.FIRESTORE_EMULATOR_HOST ?? '',/^(127\.0\.0\.1|localhost):\d+$/,'Only a loopback emulator is permitted');
 env=await initializeTestEnvironment({projectId:'demo-reach-sync-proposal',firestore:{rules:await readFile('../sync-proposal/firestore.proposed.rules','utf8')}});
});
beforeEach(async()=>{
 await env.clearFirestore();
 await admin(pairPath,{hostUid:'a',partnerUid:'b',revoked:false});
 for(const uid of ['a','b']) await admin(`nativeStaging/v1/memberLocks/${uid}`,{pairCode:code});
});
after(async()=>env?.cleanup());
test('both paired members read; unauthenticated and outsiders cannot read/list/write',async()=>{
 await assertSucceeds(setDoc(doc(db('a'),path,'m1'),entry()));
 for(const uid of ['a','b']) await assertSucceeds(getDoc(doc(db(uid),path,'m1')));
 for(const uid of [null,'outsider']) {
  await assertFails(getDoc(doc(db(uid),path,'m1')));
  await assertFails(getDocs(collection(db(uid),path)));
  await assertFails(setDoc(doc(db(uid),path,'m2'),entry(uid ?? 'a')));
 }
});
test('revocation denies further reads, updates and deletes even to former author',async()=>{
 await setDoc(doc(db('a'),path,'m1'),entry());
 await admin(pairPath,{hostUid:'a',partnerUid:'b',revoked:true});
 await assertFails(getDoc(doc(db('a'),path,'m1')));
 await assertFails(updateDoc(doc(db('a'),path,'m1'),{text:'x',updatedAt:serverTimestamp(),consentedAt:serverTimestamp()}));
 await assertFails(deleteDoc(doc(db('a'),path,'m1')));
});
test('missing/mismatched locks, missing pairs and malformed pairs fail closed',async()=>{
 for(const pair of [{hostUid:'a',partnerUid:null},{hostUid:'a/b',partnerUid:'b'},{hostUid:'a',partnerUid:42}]) {
  await admin(pairPath,pair);
  await assertFails(getDoc(doc(db('a'),path,'m1')));
 }
 await admin(pairPath,{hostUid:'a',partnerUid:'b'});
 await admin('nativeStaging/v1/memberLocks/b',{pairCode:'MNPQRSTVWXYZ'});
 await assertFails(setDoc(doc(db('a'),path,'m1'),entry()));
 await env.withSecurityRulesDisabled(async c=>{
  await deleteDoc(doc(c.firestore(),'nativeStaging/v1/memberLocks/b'));
 });
 await assertFails(getDoc(doc(db('a'),path,'m1')));
 await env.withSecurityRulesDisabled(c=>deleteDoc(doc(c.firestore(),pairPath)));
 await assertFails(getDoc(doc(db('a'),path,'m1')));
});
test('only author may edit/delete; identity, kind and createdAt cannot change',async()=>{
 await setDoc(doc(db('a'),path,'m1'),entry());
 await assertFails(updateDoc(doc(db('b'),path,'m1'),{text:'overwrite',updatedAt:serverTimestamp(),consentedAt:serverTimestamp()}));
 await assertFails(deleteDoc(doc(db('b'),path,'m1')));
 for(const patch of [{authorUid:'b'},{kind:'dateIdea'},{createdAt:Timestamp.fromMillis(0)}])
  await assertFails(updateDoc(doc(db('a'),path,'m1'),{...patch,updatedAt:serverTimestamp(),consentedAt:serverTimestamp()}));
 await assertSucceeds(updateDoc(doc(db('a'),path,'m1'),{text:'revised',updatedAt:serverTimestamp(),consentedAt:serverTimestamp()}));
 await assertSucceeds(deleteDoc(doc(db('a'),path,'m1')));
});
test('limits, schema, timestamps and absent consent receipt are rejected',async()=>{
 for(const patch of [{title:''},{title:'x'.repeat(121)},{text:'x'.repeat(6001)},{photo:'forbidden'},{authorUid:'b'},{consentedAt:null},{updatedAt:null},{category:42},{kind:'unknown'},{questionId:'foreign'}])
  await assertFails(setDoc(doc(db('a'),path,'invalid'),entry('a',patch)));
 const missing=entry();delete missing.title;
 await assertFails(setDoc(doc(db('a'),path,'invalid'),missing));
});
test('responses require an existing question in this pair; editing another response is denied',async()=>{
 await assertFails(setDoc(doc(db('b'),path,'response'),entry('b',{kind:'response',questionId:'missing'})));
 await assertFails(setDoc(doc(db('b'),path,'response'),entry('b',{kind:'response',questionId:'a/b'})));
 await setDoc(doc(db('a'),path,'q1'),entry('a',{kind:'question'}));
 await assertSucceeds(setDoc(doc(db('b'),path,'response'),entry('b',{kind:'response',questionId:'q1'})));
 await assertFails(deleteDoc(doc(db('a'),path,'response')));
});
test('unrelated native and web paths remain denied by this standalone proposal',async()=>{
 await assertFails(setDoc(doc(db('a'),'pairInvites',code),{hostUid:'a'}));
 await assertFails(setDoc(doc(db('a'),'nativeStaging/v1/rooms/room'),{active:true}));
});
