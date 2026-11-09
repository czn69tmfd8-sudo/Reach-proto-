// Run the same web contract against the supplied baseline and additive artifact.
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {after,before,beforeEach,describe,test} from 'node:test';
import {initializeTestEnvironment,assertSucceeds,assertFails} from '@firebase/rules-unit-testing';
import {doc,getDoc,getDocs,collection,setDoc,updateDoc,deleteDoc,writeBatch,serverTimestamp} from 'firebase/firestore';
import {readReview,rulesForRegression,sha256} from './prepare-rules-review.mjs';
const reviewDirectory=process.env.REACH_RULES_REVIEW_DIR || 'reviews/staging-2026-11-06-hardened';
const baseline=await readFile(reviewDirectory+'/baseline.rules','utf8');
const native=await readFile('firestore.rules','utf8');
assert.equal(sha256(baseline),'437d87ced527f053b807ba7744fc61bb74ed3a3f0e2c93e2aa61a9ca386ef86e');
const merged=process.env.REACH_RULES_REVIEW_DIR
 ? await readReview(process.env.REACH_RULES_REVIEW_DIR,native)
 : await readReview('reviews/staging-2026-11-06-hardened',native);
for(const [label,rules] of [['deployed',baseline],['additive',await rulesForRegression(merged)]]) {
 describe(`web compatibility: ${label}`,()=>{
  let env;
  const code='ABCDEFGHJKLM';
  const db=uid=>uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore();
  const pair=d=>doc(d,'pairInvites',code),lock=(d,u)=>doc(d,'memberLocks',u);
  const room=d=>doc(d,'rooms','web-room'),ice=d=>doc(d,'rooms/web-room/hostCandidates/c1');
  const candidate={candidate:'candidate:1',sdpMid:'0',sdpMLineIndex:0,usernameFragment:'web'};
  before(async()=>{env=await initializeTestEnvironment({projectId:`demo-reach-web-${label}`,firestore:{rules}})});
  beforeEach(async()=>env.clearFirestore());
  after(async()=>env?.cleanup());
  async function invite() {
   const d=db('a'),b=writeBatch(d);
   b.set(pair(d),{hostUid:'a',partnerUid:null,createdAt:serverTimestamp(),activeRoom:null,openedBy:null});
   b.set(lock(d,'a'),{pairCode:code,createdAt:serverTimestamp()});await assertSucceeds(b.commit());
  }
  async function accept() {
   const d=db('b'),b=writeBatch(d);b.update(pair(d),{partnerUid:'b'});
   b.set(lock(d,'b'),{pairCode:code,createdAt:serverTimestamp()});await assertSucceeds(b.commit());
  }
  async function paired(){await invite();await accept()}
  async function open() {
   await assertSucceeds(setDoc(room(db('a')),{hostUid:'a',partnerUid:'b',pairCode:code,createdAt:serverTimestamp(),expiresAt:Date.now()+3600000,active:true,offer:{type:'offer',sdp:'v=0\r\nweb offer'}}));
   // Deployed web publishes the pointer AFTER room creation, not atomically.
   await assertSucceeds(updateDoc(pair(db('a')),{activeRoom:'web-room',openedBy:'a'}));
  }
  test('create/accept locks and invitation lookup preserve web contracts',async()=>{
   await invite();await assertSucceeds(getDoc(pair(db('b'))));await accept();
   await assertSucceeds(getDoc(lock(db('a'),'a')));await assertSucceeds(getDoc(pair(db('b'))));
   await assertFails(getDoc(pair(db('c'))));await assertFails(getDoc(lock(db('b'),'a')));
   await assertFails(getDocs(collection(db('a'),'pairInvites')));await assertFails(getDoc(pair(db())));
  });
  test('permanent web locks remain immutable after revocation',async()=>{
   await paired();await assertSucceeds(updateDoc(pair(db('a')),{revoked:true}));
   await assertFails(deleteDoc(lock(db('a'),'a')));await assertFails(updateDoc(lock(db('a'),'a'),{pairCode:'MNPQRSTVWXYZ'}));
   const d=db('a'),b=writeBatch(d);b.set(doc(d,'pairInvites','MNPQRSTVWXYZ'),{hostUid:'a',partnerUid:null,activeRoom:null,openedBy:null,createdAt:serverTimestamp()});
   await assertFails(b.commit());
  });
  test('offer-at-creation, partner-only answer and host end still work',async()=>{
   await paired();await open();
   await assertFails(updateDoc(room(db('a')),{answer:{type:'answer',sdp:'v=0'},partnerJoinedAt:serverTimestamp()}));
   await assertSucceeds(updateDoc(room(db('b')),{answer:{type:'answer',sdp:'v=0'},partnerJoinedAt:serverTimestamp()}));
   await assertFails(updateDoc(room(db('b')),{offer:{type:'offer',sdp:'replace'}}));
   await assertSucceeds(updateDoc(room(db('a')),{active:false,endedAt:serverTimestamp()}));
   await assertSucceeds(updateDoc(pair(db('a')),{activeRoom:null,openedBy:null}));
  });
  test('web ICE direction, optional fields and revocation preserved',async()=>{
   await paired();await open();await assertSucceeds(setDoc(ice(db('a')),candidate));
   await assertSucceeds(getDocs(collection(db('b'),'rooms/web-room/hostCandidates')));
   await assertFails(setDoc(doc(db('b'),'rooms/web-room/hostCandidates/c2'),candidate));
   await assertFails(getDoc(ice(db('c'))));await assertFails(updateDoc(pair(db('c')),{revoked:true}));
   await assertSucceeds(updateDoc(pair(db('b')),{revoked:true}));
   await assertFails(getDoc(room(db('a'))));await assertFails(getDoc(ice(db('a'))));
  });
  test('each member edits only own profile photo',async()=>{
   await paired();const photo='data:image/jpeg;base64,YQ==';
   await assertSucceeds(updateDoc(pair(db('a')),{profilePhotos:{a:photo}}));
   await assertSucceeds(updateDoc(pair(db('b')),{profilePhotos:{a:photo,b:photo}}));
   await assertFails(updateDoc(pair(db('a')),{profilePhotos:{a:photo,b:'data:image/jpeg;base64,Yg=='}}));
   await assertFails(updateDoc(pair(db('a')),{profilePhotos:{a:'not a photo',b:photo}}));
   assert.equal((await getDoc(pair(db('b')))).data().profilePhotos.a,photo);
  });
  test('daily answers preserve ownership, fixed question and length limit',async()=>{
   await paired();const answer=uid=>({uid,questionId:'2026-10-17-grateful',text:'Grateful for us',submittedAt:1});
   const host=answer('a'),partner=answer('b');
   await assertSucceeds(updateDoc(pair(db('a')),{dailyQuestionAnswers:{host}}));
   await assertSucceeds(updateDoc(pair(db('b')),{dailyQuestionAnswers:{host,partner}}));
   await assertFails(updateDoc(pair(db('a')),{dailyQuestionAnswers:{host,partner:{...partner,text:'overwrite'}}}));
   await assertFails(updateDoc(pair(db('a')),{dailyQuestionAnswers:{host:{...host,text:'x'.repeat(601)},partner}}));
   await assertFails(updateDoc(pair(db('a')),{dailyQuestionAnswers:{host:{...host,questionId:'other'},partner}}));
  });
  test('older paired records without locks remain usable and retain extra fields',async()=>{
   await env.withSecurityRulesDisabled(async c=>setDoc(pair(c.firestore()),{hostUid:'a',partnerUid:'b',createdAt:new Date(0),activeRoom:null,openedBy:null,profilePhotos:{a:'existing'},dailyQuestionAnswers:{host:{text:'existing'}}}));
   await assertSucceeds(getDoc(pair(db('a'))));await open();
   const data=(await getDoc(pair(db('b')))).data();assert.equal(data.profilePhotos.a,'existing');assert.equal(data.dailyQuestionAnswers.host.text,'existing');
  });
  test('legacy expiry reads retained while new ICE writes expire',async()=>{
   await paired();await open();await assertSucceeds(setDoc(ice(db('a')),candidate));
   await env.withSecurityRulesDisabled(async c=>updateDoc(room(c.firestore()),{expiresAt:Date.now()-1000}));
   await assertSucceeds(getDoc(room(db('a'))));await assertSucceeds(getDoc(ice(db('b'))));
   await assertFails(setDoc(doc(db('a'),'rooms/web-room/hostCandidates/c2'),candidate));
  });
  test('unknown roots and unauthenticated native requests remain denied',async()=>{
   await assertFails(setDoc(doc(db('a'),'unknown/doc'),{value:true}));
   await assertFails(getDoc(doc(db(),'nativeStaging/v1/pairInvites',code)));
  });
 });
}
