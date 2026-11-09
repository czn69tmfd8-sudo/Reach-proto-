import {readFile} from 'node:fs/promises';
import {after, before, beforeEach, test} from 'node:test';
import {initializeTestEnvironment, assertSucceeds, assertFails} from '@firebase/rules-unit-testing';
import {doc, getDoc, getDocs, collection, setDoc, updateDoc, deleteDoc, writeBatch, serverTimestamp} from 'firebase/firestore';

let env;
const code = 'ABCDEFGHJKLM';
const db = uid => uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore();
const pair = d => doc(d,'pairInvites',code);
const lock = (d,u) => doc(d,'memberLocks',u);
const room = (d,id='r1') => doc(d,'rooms',id);
const ice = (d,side='hostCandidates',id='c1') => doc(d,'rooms/r1/'+side,id);
const candidate = {candidate:'candidate:1 1 UDP 123 192.0.2.1 12345 typ host',sdpMid:'0',sdpMLineIndex:0};
async function invite() {
 const d=db('a'), b=writeBatch(d);
 b.set(pair(d),{hostUid:'a',partnerUid:null,activeRoom:null,openedBy:null,createdAt:serverTimestamp()});
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
async function adminPatch(path,data) { await env.withSecurityRulesDisabled(async c=>updateDoc(doc(c.firestore(),path),data)); }
before(async()=>{env=await initializeTestEnvironment({projectId:'demo-reach-legacy',firestore:{rules:await readFile('fixtures/8956bb8-shared-collections.rules','utf8')}})});
beforeEach(async()=>env.clearFirestore());
after(async()=>env?.cleanup());
test('fresh installations create and accept atomically, persist own locks',async()=>{
 await invite(); await assertSucceeds(accept());
 await assertSucceeds(getDoc(lock(db('a'),'a'))); await assertSucceeds(getDoc(lock(db('b'),'b')));
 await assertFails(getDoc(lock(db('a'),'b'))); await assertFails(getDoc(pair(db('c'))));
});
test('anonymous requests and invitation enumeration are denied',async()=>{
 await invite(); await assertFails(getDoc(pair(db()))); await assertFails(getDocs(collection(db('b'),'pairInvites')));
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
 await assertSucceeds(getDocs(collection(db('b'),'rooms/r1/hostCandidates')));
 await assertFails(setDoc(ice(db('b'),'hostCandidates','c2'),candidate));
 await assertSucceeds(setDoc(ice(db('b'),'partnerCandidates'),candidate));
 await assertFails(getDocs(collection(db('c'),'rooms/r1/hostCandidates')));
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
 b.update(pair(d),{revoked:true,activeRoom:null,openedBy:null}); b.update(room(d),{active:false,endedAt:serverTimestamp()});
 await assertSucceeds(b.commit());
 await assertFails(getDoc(room(db('a')))); await assertFails(setDoc(ice(db('a')),candidate)); await assertFails(getDocs(collection(db('a'),'rooms/r1/hostCandidates')));
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
