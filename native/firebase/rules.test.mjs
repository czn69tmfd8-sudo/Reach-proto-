import assert from 'node:assert/strict';
import {readReview,sha256} from './prepare-rules-review.mjs';
import {readFile} from 'node:fs/promises';
import {after, before, beforeEach, test} from 'node:test';
import {initializeTestEnvironment, assertSucceeds, assertFails} from '@firebase/rules-unit-testing';
import {doc, getDoc, getDocs, collection, setDoc, updateDoc, deleteDoc, writeBatch, serverTimestamp} from 'firebase/firestore';

let env;
const code = 'ABCDEFGHJKLM';
const root = 'nativeStaging/v1/';
const db = uid => uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore();
const pair = d => doc(d,root+'pairInvites',code);
const lock = (d,u) => doc(d,root+'memberLocks',u);
const room = (d,id='r1') => doc(d,root+'rooms',id);
const ice = (d,side='hostCandidates',id='c1') => doc(d,root+'rooms/r1/'+side,id);
const candidate = {candidate:'candidate:1 1 UDP 123 192.0.2.1 12345 typ host',sdpMid:'0',sdpMLineIndex:0};
async function invite() {
 const d=db('a'), b=writeBatch(d);
 b.set(pair(d),{hostUid:'a',partnerUid:null,activeRoom:null,openedBy:null,createdAt:serverTimestamp(),expiresAt:Date.now()+25*60000});
 b.set(lock(d,'a'),{pairCode:code,createdAt:serverTimestamp()});
 await assertSucceeds(b.commit());
}
async function accept(uid='b') {
 const d=db(uid), b=writeBatch(d);
 b.update(pair(d),{partnerUid:uid}); b.set(lock(d,uid),{pairCode:code,createdAt:serverTimestamp()});
 return b.commit();
}
async function open(uid='a',id='r1') {
 const d=db(uid),b=writeBatch(d);
 b.set(room(d,id),{hostUid:uid,partnerUid:uid==='a'?'b':'a',pairCode:code,createdAt:serverTimestamp(),expiresAt:Date.now()+3600000,active:true});
 b.update(pair(d),{activeRoom:id,openedBy:uid}); return b.commit();
}
async function fixture() { await invite(); await assertSucceeds(accept()); await assertSucceeds(open()); }
async function adminPatch(path,data) { await env.withSecurityRulesDisabled(async c=>updateDoc(doc(c.firestore(),root+path),data)); }
before(async()=>{
 const legacy=await readFile('fixtures/deployed-staging-2026-11-05.rules','utf8');
 assert.equal(sha256(legacy),'63f06d53574e186e933c8629099439f94d554798322363eaad5edb0d1a1bfeeb');
 const native=await readFile('firestore.rules','utf8');
 const combined=process.env.REACH_RULES_REVIEW_DIR
  ? await readReview(process.env.REACH_RULES_REVIEW_DIR,native)
  : await readReview('reviews/staging-2026-11-05',native);
 env=await initializeTestEnvironment({projectId:'demo-reach-native',firestore:{rules:combined}});
});
beforeEach(async()=>env.clearFirestore());
after(async()=>env?.cleanup());
test('fresh installations create and accept atomically, persist own locks',async()=>{
 await invite(); await assertSucceeds(accept());
 await assertSucceeds(getDoc(lock(db('a'),'a'))); await assertSucceeds(getDoc(lock(db('b'),'b')));
 await assertFails(getDoc(lock(db('a'),'b'))); await assertFails(getDoc(pair(db('c'))));
});
test('anonymous requests and invitation enumeration are denied',async()=>{
 await invite(); await assertFails(getDoc(pair(db()))); await assertFails(getDocs(collection(db('b'),root+'pairInvites')));
});
test('accept without atomic lock, self acceptance and second acceptance denied',async()=>{
 await invite(); await assertFails(updateDoc(pair(db('b')),{partnerUid:'b'})); await assertFails(accept('a'));
 await assertSucceeds(accept()); await assertFails(accept('c'));
});
test('locks cannot be deleted or reassigned',async()=>{
 await invite(); await assertFails(deleteDoc(lock(db('a'),'a'))); await assertFails(updateDoc(lock(db('a'),'a'),{pairCode:'OTHER'}));
});
test('only opener offers, only partner answers, descriptions immutable',async()=>{
 await fixture(); const offer={type:'offer',sdp:'v=0\r\no=test'},answer={type:'answer',sdp:'v=0\r\no=answer'};
 await assertFails(updateDoc(room(db('b')),{offer})); await assertFails(updateDoc(room(db('b')),{answer}));
 await assertSucceeds(updateDoc(room(db('a')),{offer})); await assertFails(updateDoc(room(db('a')),{offer}));
 await assertFails(updateDoc(room(db('a')),{answer})); await assertSucceeds(updateDoc(room(db('b')),{answer}));
 await assertFails(updateDoc(room(db('c')),{answer})); await assertFails(getDoc(room(db('c'))));
});
test('ICE directions enforced and both partners can receive',async()=>{
 await fixture(); await assertSucceeds(setDoc(ice(db('a')),candidate));
 await assertSucceeds(getDocs(collection(db('b'),root+'rooms/r1/hostCandidates')));
 await assertFails(setDoc(ice(db('b'),'hostCandidates','c2'),candidate));
 await assertSucceeds(setDoc(ice(db('b'),'partnerCandidates'),candidate));
 await assertFails(getDocs(collection(db('c'),root+'rooms/r1/hostCandidates')));
 await assertFails(updateDoc(ice(db('a')),{candidate:'replace'}));
});
test('malformed or oversized signaling rejected',async()=>{
 await fixture(); await assertFails(updateDoc(room(db('a')),{offer:{type:'answer',sdp:'x'}}));
 await assertFails(updateDoc(room(db('a')),{offer:{type:'offer',sdp:'x'.repeat(256001)}}));
 for (const value of [{...candidate,sdpMLineIndex:-1},{...candidate,candidate:''},{...candidate,candidate:'x'.repeat(8001)},{...candidate,extra:true}]) {
  await assertFails(setDoc(ice(db('a')),value));
 }
});
test('duplicate sessions cannot overwrite active pointer',async()=>{
 await fixture(); await assertFails(open('a','r2')); await assertFails(open('b','r3'));
});
test('revocation atomically ends room and prevents all further signaling and new rooms',async()=>{
 await fixture(); const d=db('b'),b=writeBatch(d);
 b.update(pair(d),{revoked:true,revokedBy:'b',revokedAt:serverTimestamp(),activeRoom:null,openedBy:null}); b.update(room(d),{active:false,endedAt:serverTimestamp()});
 await assertSucceeds(b.commit());
 await assertFails(getDoc(room(db('a')))); await assertFails(setDoc(ice(db('a')),candidate)); await assertFails(getDocs(collection(db('a'),root+'rooms/r1/hostCandidates')));
 await assertFails(updateDoc(room(db('a')),{offer:{type:'offer',sdp:'v=0'}})); await assertFails(open('a','r2'));
 await assertFails(updateDoc(pair(db('a')),{revoked:false}));
});
test('outsiders cannot revoke or end sessions',async()=>{
 await fixture(); await assertFails(updateDoc(pair(db('c')),{revoked:true,activeRoom:null,openedBy:null}));
 await assertFails(updateDoc(room(db('c')),{active:false,endedAt:serverTimestamp()}));
});
test('cleanup ends old room without erasing newer pointer',async()=>{
 await fixture(); const d=db('a'), b=writeBatch(d);
 b.update(room(d),{active:false,endedAt:serverTimestamp()}); b.update(pair(d),{activeRoom:null,openedBy:null}); await assertSucceeds(b.commit());
 await assertSucceeds(open('b','r2')); await assertSucceeds(updateDoc(room(d),{active:false,endedAt:serverTimestamp()}));
 const stale=writeBatch(d); stale.update(room(d),{active:false,endedAt:serverTimestamp()}); stale.update(pair(d),{activeRoom:null,openedBy:null});
 await assertFails(stale.commit()); await assertFails(setDoc(ice(d),candidate));
});
test('expired sessions, mismatched pair membership and stale locks fail closed',async()=>{
 await fixture(); await adminPatch('rooms/r1',{expiresAt:Date.now()-1000}); await assertFails(setDoc(ice(db('a')),candidate));
 await adminPatch('rooms/r1',{expiresAt:Date.now()+60000,partnerUid:'c'}); await assertFails(setDoc(ice(db('a')),candidate));
 await adminPatch('rooms/r1',{partnerUid:'b'}); await adminPatch('memberLocks/b',{pairCode:'OTHER'}); await assertFails(setDoc(ice(db('a')),candidate));
});

const secondCode='MNPQRSTVWXYZ';
async function createFor(uid,c=secondCode) {
 const d=db(uid),b=writeBatch(d);
 b.set(doc(d,root+'pairInvites',c),{hostUid:uid,partnerUid:null,activeRoom:null,openedBy:null,createdAt:serverTimestamp(),expiresAt:Date.now()+25*60000});
 b.set(lock(d,uid),{pairCode:c,createdAt:serverTimestamp()});
 return b.commit();
}
async function acceptFor(uid,c=secondCode) {
 const d=db(uid),b=writeBatch(d);
 b.update(doc(d,root+'pairInvites',c),{partnerUid:uid});
 b.set(lock(d,uid),{pairCode:c,createdAt:serverTimestamp()});
 return b.commit();
}
async function revokeFor(uid='a') {
 return updateDoc(pair(db(uid)),{revoked:true,revokedBy:uid,revokedAt:serverTimestamp(),activeRoom:null,openedBy:null});
}
test('same authenticated users re-pair only after authorized revocation, retaining old pair audit',async()=>{
 await fixture(); await assertFails(createFor('a')); await assertSucceeds(revokeFor());
 await assertSucceeds(createFor('a')); await assertSucceeds(acceptFor('b'));
 const old=(await getDoc(pair(db('a')))).data();
 assert.equal(old.revoked,true);assert.equal(old.hostUid,'a');assert.equal(old.partnerUid,'b');assert.equal(old.revokedBy,'a');assert.ok(old.revokedAt);
 assert.equal((await getDoc(lock(db('a'),'a'))).data().pairCode,secondCode);
 assert.equal((await getDoc(lock(db('b'),'b'))).data().pairCode,secondCode);
 await assertFails(getDoc(room(db('a'))));await assertFails(setDoc(ice(db('b'),'partnerCandidates','late'),candidate));
 await assertFails(updateDoc(pair(db('a')),{revoked:false}));
});
test('revoked former partners may independently re-pair without moving the other users lock',async()=>{
 await fixture();await assertSucceeds(revokeFor('b'));await assertSucceeds(createFor('b'));await assertSucceeds(acceptFor('c'));
 assert.equal((await getDoc(lock(db('a'),'a'))).data().pairCode,code);
 await assertFails(updateDoc(lock(db('a'),'b'),{pairCode:code,createdAt:serverTimestamp()}));
 await assertFails(getDoc(doc(db('a'),root+'pairInvites',secondCode)));
});
test('revocation cannot spoof audit identity/time or mutate partnership membership',async()=>{
 await fixture();
 for(const value of [
  {revoked:true,revokedBy:'b',revokedAt:serverTimestamp(),activeRoom:null,openedBy:null},
  {revoked:true,revokedBy:'a',revokedAt:null,activeRoom:null,openedBy:null},
  {revoked:true,revokedBy:'a',revokedAt:serverTimestamp(),hostUid:'c',activeRoom:null,openedBy:null}
 ]) await assertFails(updateDoc(pair(db('a')),value));
});
test('expired invitation cannot be read by outsiders or accepted, but owner can revoke and start fresh',async()=>{
 await invite();await adminPatch('pairInvites/'+code,{expiresAt:Date.now()-1});
 await assertSucceeds(getDoc(pair(db('a'))));await assertFails(getDoc(pair(db('b'))));await assertFails(accept());
 await assertFails(createFor('a'));await assertSucceeds(revokeFor());await assertSucceeds(createFor('a'));
});
test('revocation succeeds with a missing room pointer and no room read',async()=>{
 await fixture();await adminPatch('pairInvites/'+code,{activeRoom:'missing'});
 await assertSucceeds(revokeFor());await assertSucceeds(createFor('a'));
 await assertFails(getDoc(room(db('b'))));await assertFails(setDoc(ice(db('b'),'partnerCandidates'),candidate));
});
test('revocation does not depend on expired SDP read access',async()=>{
 await fixture();await adminPatch('rooms/r1',{expiresAt:Date.now()-1});
 await assertFails(getDoc(room(db('a'))));await assertSucceeds(revokeFor());
 await assertSucceeds(updateDoc(room(db('a')),{pairCode:code,active:false,endedAt:serverTimestamp()}));
});
test('all SDP/ICE reads and writes deny at expiry, cleanup remains authorized',async()=>{
 await fixture();await assertSucceeds(updateDoc(room(db('a')),{offer:{type:'offer',sdp:'v=0'}}));
 await assertSucceeds(setDoc(ice(db('a')),candidate));await adminPatch('rooms/r1',{expiresAt:Date.now()-1});
 for(const uid of ['a','b']) {
  await assertFails(getDoc(room(db(uid))));
  await assertFails(getDoc(ice(db(uid))));
  await assertFails(getDocs(collection(db(uid),root+'rooms/r1/hostCandidates')));
 }
 await assertFails(updateDoc(room(db('b')),{answer:{type:'answer',sdp:'v=0'}}));
 await assertFails(setDoc(ice(db('b'),'partnerCandidates'),candidate));
 const d=db('a'),b=writeBatch(d);
 b.update(room(d),{pairCode:code,active:false,endedAt:serverTimestamp()});b.update(pair(d),{activeRoom:null,openedBy:null});
 await assertSucceeds(b.commit());await assertSucceeds(open('b','fresh-room'));
});
test('ending a room denies its payload and candidates even before its timestamp expires',async()=>{
 await fixture();await assertSucceeds(setDoc(ice(db('a')),candidate));
 const d=db('a'),b=writeBatch(d);b.update(room(d),{pairCode:code,active:false,endedAt:serverTimestamp()});b.update(pair(d),{activeRoom:null,openedBy:null});await assertSucceeds(b.commit());
 await assertFails(getDoc(room(db('a'))));await assertFails(getDoc(ice(db('b'))));
});
test('cleanup cannot change a rooms pairCode, reopen it or create a sparse missing room',async()=>{
 await fixture();
 await assertFails(updateDoc(room(db('a')),{pairCode:'WRONG',active:false,endedAt:serverTimestamp()}));
 await assertFails(updateDoc(room(db('a'),'missing'),{pairCode:code,active:false,endedAt:serverTimestamp()}));
 await assertSucceeds(updateDoc(room(db('a')),{active:false,endedAt:serverTimestamp()}));
 await assertFails(updateDoc(room(db('a')),{active:true}));
});
test('simultaneous acceptances allow exactly one partner and leave no loser lock',async()=>{
 await invite();const results=await Promise.allSettled([accept('b'),accept('c')]);
 assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
 const loser=results[0].status==='rejected'?'b':'c';assert.equal((await getDoc(lock(db(loser),loser))).exists(),false);
});
test('simultaneous open attempts allow only one room for the pair',async()=>{
 await invite();await assertSucceeds(accept());
 const results=await Promise.allSettled([open('a','first'),open('b','second')]);
 assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
});
test('native create accept revoke and re-pair leave all pre-existing web documents unchanged',async()=>{
 const records={
  'pairInvites/WEB123':{hostUid:'a',partnerUid:'b',activeRoom:'web-room',openedBy:'a',profilePhotos:{a:'photo'},custom:'keep'},
  'memberLocks/a':{pairCode:'WEB123',legacy:true},'memberLocks/b':{pairCode:'WEB123'},
  'rooms/web-room':{pairCode:'WEB123',active:true,hostUid:'a',partnerUid:'b',offer:{sdp:'web-offer'}},
  'rooms/web-room/hostCandidates/keep':{candidate:'web-candidate'}
 };
 await env.withSecurityRulesDisabled(async c=>{for(const [path,data] of Object.entries(records))await setDoc(doc(c.firestore(),path),data)});
 await fixture();await assertSucceeds(revokeFor());await assertSucceeds(createFor('a'));await assertSucceeds(acceptFor('b'));
 await env.withSecurityRulesDisabled(async c=>{for(const [path,data] of Object.entries(records))assert.deepEqual((await getDoc(doc(c.firestore(),path))).data(),data)});
});
test('invitation and room expiry cannot be extended by their members',async()=>{
 await invite();await assertFails(updateDoc(pair(db('a')),{expiresAt:Date.now()+999999999}));
 await assertSucceeds(accept());await assertSucceeds(open());await assertFails(updateDoc(room(db('a')),{expiresAt:Date.now()+999999999}));
});

test('same UIDs and codes use separate native and permanent web locks',async()=>{
 // Native users must never inherit, revoke or migrate existing web pairing data.
 const d=db('a');
 await env.withSecurityRulesDisabled(async c=>{
  const w=c.firestore();await setDoc(doc(w,'memberLocks','a'),{pairCode:code,createdAt:new Date(0)});
  await setDoc(doc(w,'pairInvites',code),{hostUid:'a',partnerUid:'b',createdAt:new Date(0),activeRoom:null,openedBy:null,profilePhotos:{a:'keep'},dailyQuestionAnswers:{host:{text:'keep'}}});
 });
 const old=(await getDoc(doc(d,'pairInvites',code))).data();
 await invite();await assertSucceeds(accept());await assertSucceeds(open());
 await assertSucceeds(revokeFor());await assertSucceeds(createFor('a'));await assertSucceeds(acceptFor('b'));
 assert.deepEqual((await getDoc(doc(d,'pairInvites',code))).data(),old);
 assert.equal((await getDoc(doc(d,'memberLocks','a'))).data().pairCode,code);
 assert.equal((await getDoc(lock(d,'a'))).data().pairCode,secondCode);
});
test('web records cannot authorize native room or candidate access',async()=>{
 await env.withSecurityRulesDisabled(async c=>{
  const d=c.firestore();await setDoc(doc(d,'pairInvites',code),{hostUid:'a',partnerUid:'b',activeRoom:'r1',openedBy:'a'});
  await setDoc(doc(d,'memberLocks','a'),{pairCode:code});await setDoc(doc(d,'memberLocks','b'),{pairCode:code});
 });
 await assertFails(open());await assertFails(setDoc(ice(db('a')),candidate));
 await assertFails(getDoc(room(db('b'))));
});
