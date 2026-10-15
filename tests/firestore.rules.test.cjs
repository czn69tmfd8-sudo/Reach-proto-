const {before,after,test}=require('node:test');
const assert=require('node:assert/strict');
const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {doc,setDoc,getDoc,updateDoc,collection,addDoc,getDocs,runTransaction,serverTimestamp,deleteDoc}=require('firebase/firestore');
const fs=require('node:fs');
let env;
const projectId='reach-security-test';
const pairCode='ABCDEFGHJKLM';
const roomCode='ABCDEF';
const now=Date.now();
before(async()=>{
 env=await initializeTestEnvironment({projectId,firestore:{host:'127.0.0.1',port:8080,rules:fs.readFileSync('../firestore.security-candidate.rules','utf8')}});
 await env.withSecurityRulesDisabled(async context=>{
  const db=context.firestore();
  await setDoc(doc(db,'pairInvites',pairCode),{hostUid:'host',partnerUid:'partner',activeRoom:roomCode,openedBy:'host',createdAt:new Date()});
  await setDoc(doc(db,'rooms',roomCode),{hostUid:'host',partnerUid:'partner',pairCode,createdAt:new Date(),expiresAt:now+3600000,active:true,offer:{type:'offer',sdp:'offer'}});
 });
});
after(async()=>{if(env)await env.cleanup()});
const db=(uid)=>env.authenticatedContext(uid).firestore();
test('host and partner can read their room',async()=>{
 await assertSucceeds(getDoc(doc(db('host'),'rooms',roomCode)));
 await assertSucceeds(getDoc(doc(db('partner'),'rooms',roomCode)));
});
test('outsider cannot read room or candidates',async()=>{
 await assertFails(getDoc(doc(db('outsider'),'rooms',roomCode)));
 await assertFails(getDocs(collection(db('outsider'),'rooms',roomCode,'hostCandidates')));
});
test('outsider cannot list rooms',async()=>{await assertFails(getDocs(collection(db('outsider'),'rooms')))});
test('host cannot write partner ICE',async()=>{
 await assertFails(addDoc(collection(db('host'),'rooms',roomCode,'partnerCandidates'),{candidate:'candidate:1',sdpMid:'0',sdpMLineIndex:0}));
});
test('partner cannot write host ICE',async()=>{
 await assertFails(addDoc(collection(db('partner'),'rooms',roomCode,'hostCandidates'),{candidate:'candidate:1',sdpMid:'0',sdpMLineIndex:0}));
});
test('host can write host ICE',async()=>{
 await assertSucceeds(addDoc(collection(db('host'),'rooms',roomCode,'hostCandidates'),{candidate:'candidate:1',sdpMid:'0',sdpMLineIndex:0}));
});
test('partner can write partner ICE',async()=>{
 await assertSucceeds(addDoc(collection(db('partner'),'rooms',roomCode,'partnerCandidates'),{candidate:'candidate:1',sdpMid:'0',sdpMLineIndex:0}));
});
test('outsider cannot change pairing',async()=>{
 await assertFails(updateDoc(doc(db('outsider'),'pairInvites',pairCode),{activeRoom:null,openedBy:null}));
});
test('partner cannot clear host open hand',async()=>{
 await assertFails(updateDoc(doc(db('partner'),'pairInvites',pairCode),{activeRoom:null,openedBy:null}));
});
test('host can clear own open hand',async()=>{
 await assertSucceeds(updateDoc(doc(db('host'),'pairInvites',pairCode),{activeRoom:null,openedBy:null}));
});

test('revoked pairing denies both partners room and candidate access',async()=>{
 const code='REVOKEDPAIR1',room='REVOKE';
 await env.withSecurityRulesDisabled(async c=>{
  const d=c.firestore();
  await setDoc(doc(d,'pairInvites',code),{hostUid:'revHost',partnerUid:'revPartner',activeRoom:room,openedBy:'revHost',createdAt:new Date(),revoked:true});
  await setDoc(doc(d,'rooms',room),{hostUid:'revHost',partnerUid:'revPartner',pairCode:code,createdAt:new Date(),expiresAt:Date.now()+3600000,active:true,offer:{type:'offer',sdp:'offer'}});
 });
 await assertFails(getDoc(doc(db('revHost'),'rooms',room)));
 await assertFails(getDocs(collection(db('revPartner'),'rooms',room,'hostCandidates')));
 await assertFails(getDoc(doc(db('revHost'),'pairInvites',code)));
});
test('expired rooms deny fresh candidate writes and partner answers',async()=>{
 const code='EXPIREDPAIR1',room='EXPIRE';
 await env.withSecurityRulesDisabled(async c=>{
  const d=c.firestore();
  await setDoc(doc(d,'pairInvites',code),{hostUid:'expHost',partnerUid:'expPartner',activeRoom:room,openedBy:'expHost',createdAt:new Date()});
  await setDoc(doc(d,'rooms',room),{hostUid:'expHost',partnerUid:'expPartner',pairCode:code,createdAt:new Date(),expiresAt:Date.now()-10000,active:true,offer:{type:'offer',sdp:'offer'}});
 });
 await assertFails(addDoc(collection(db('expHost'),'rooms',room,'hostCandidates'),{candidate:'candidate:1'}));
 await assertFails(updateDoc(doc(db('expPartner'),'rooms',room),{answer:{type:'answer',sdp:'answer'},partnerJoinedAt:new Date()}));
});
test('partner cannot alter the host photo or identities',async()=>{
 const code='PHOTOPAIRA12';
 await env.withSecurityRulesDisabled(async c=>{
  await setDoc(doc(c.firestore(),'pairInvites',code),{
   hostUid:'photoHost',partnerUid:'photoPartner',activeRoom:null,openedBy:null,createdAt:new Date(),
   profilePhotos:{photoHost:'data:image/jpeg;base64,YWJj'}
  });
 });
 await assertFails(updateDoc(doc(db('photoPartner'),'pairInvites',code),{'profilePhotos.photoHost':'data:image/jpeg;base64,ZGVm'}));
 await assertFails(updateDoc(doc(db('photoPartner'),'pairInvites',code),{hostUid:'photoPartner'}));
 await assertSucceeds(updateDoc(doc(db('photoPartner'),'pairInvites',code),{'profilePhotos.photoPartner':'data:image/jpeg;base64,YWJj'}));
});
test('member lock is private, immutable, and cannot be removed by its owner',async()=>{
 await env.withSecurityRulesDisabled(async c=>{
  await setDoc(doc(c.firestore(),'memberLocks','lockedHost'),{pairCode:'LOCKEDPAIR12',createdAt:new Date()});
 });
 await assertFails(getDoc(doc(db('outsider'),'memberLocks','lockedHost')));
 await assertSucceeds(getDoc(doc(db('lockedHost'),'memberLocks','lockedHost')));
 await assertFails(updateDoc(doc(db('lockedHost'),'memberLocks','lockedHost'),{pairCode:'ANOTHERPAIR1'}));
});
test('locked account cannot read a different legacy pairing',async()=>{
 const code='LEGACYPAIR12',room='LEGACY';
 await env.withSecurityRulesDisabled(async c=>{
  const d=c.firestore();
  await setDoc(doc(d,'pairInvites',code),{hostUid:'lockedHost',partnerUid:'legacyPartner',activeRoom:room,openedBy:'lockedHost',createdAt:new Date()});
  await setDoc(doc(d,'rooms',room),{hostUid:'lockedHost',partnerUid:'legacyPartner',pairCode:code,createdAt:new Date(),expiresAt:Date.now()+3600000,active:true,offer:{type:'offer',sdp:'offer'}});
 });
 await assertFails(getDoc(doc(db('lockedHost'),'rooms',room)));
});

test('locked account cannot directly read or modify a different legacy pairing',async()=>{
 const code='LEGACYPAIR12';
 await assertFails(getDoc(doc(db('lockedHost'),'pairInvites',code)));
 await assertFails(updateDoc(doc(db('lockedHost'),'pairInvites',code),{revoked:true}));
 await assertSucceeds(getDoc(doc(db('legacyPartner'),'pairInvites',code)));
});

test('new pairing requires its member lock in the same transaction',async()=>{
 const uid='newHostA',code='NEWPAIRCODE1',d=db(uid);
 await assertFails(setDoc(doc(d,'pairInvites',code),{hostUid:uid,partnerUid:null,activeRoom:null,openedBy:null,createdAt:serverTimestamp()}));
 await assertSucceeds(runTransaction(d,async tx=>{
  const lock=doc(d,'memberLocks',uid);
  assert.equal((await tx.get(lock)).exists(),false);
  tx.set(doc(d,'pairInvites',code),{hostUid:uid,partnerUid:null,activeRoom:null,openedBy:null,createdAt:serverTimestamp()});
  tx.set(lock,{pairCode:code,createdAt:serverTimestamp()});
 }));
 await assertSucceeds(getDoc(doc(d,'memberLocks',uid)));
});
test('claiming a pairing requires an atomic member lock',async()=>{
 const host='newHostB',partner='newPartnerB',code='NEWPAIRCODE2',hostDb=db(host),partnerDb=db(partner);
 await assertSucceeds(runTransaction(hostDb,async tx=>{
  const lock=doc(hostDb,'memberLocks',host);
  await tx.get(lock);
  tx.set(doc(hostDb,'pairInvites',code),{hostUid:host,partnerUid:null,activeRoom:null,openedBy:null,createdAt:serverTimestamp()});
  tx.set(lock,{pairCode:code,createdAt:serverTimestamp()});
 }));
 await assertFails(updateDoc(doc(partnerDb,'pairInvites',code),{partnerUid:partner}));
 await assertSucceeds(runTransaction(partnerDb,async tx=>{
  const lock=doc(partnerDb,'memberLocks',partner);
  const pair=doc(partnerDb,'pairInvites',code);
  assert.equal((await tx.get(lock)).exists(),false);
  assert.equal((await tx.get(pair)).data().partnerUid,null);
  tx.update(pair,{partnerUid:partner});
  tx.set(lock,{pairCode:code,createdAt:serverTimestamp()});
 }));
 await assertSucceeds(getDoc(doc(partnerDb,'memberLocks',partner)));
});
test('an already-locked account cannot create a second pairing',async()=>{
 const uid='newHostA',code='SECONDPAIR12',d=db(uid);
 await assertFails(setDoc(doc(d,'pairInvites',code),{hostUid:uid,partnerUid:null,activeRoom:null,openedBy:null,createdAt:serverTimestamp()}));
 await assertFails(runTransaction(d,async tx=>{
  const pair=doc(d,'pairInvites',code);
  tx.set(pair,{hostUid:uid,partnerUid:null,activeRoom:null,openedBy:null,createdAt:serverTimestamp()});
  tx.set(doc(d,'memberLocks',uid),{pairCode:code,createdAt:serverTimestamp()});
 }));
});
test('a pairing lock cannot be deleted by its owner',async()=>{
 await assertFails(deleteDoc(doc(db('newHostA'),'memberLocks','newHostA')));
});

test('existing paired users cannot be silently locked without explicit migration',async()=>{
 const code='EXISTINGPAIR',host='existingHost',partner='existingPartner';
 await env.withSecurityRulesDisabled(async c=>{
  await setDoc(doc(c.firestore(),'pairInvites',code),{hostUid:host,partnerUid:partner,activeRoom:null,openedBy:null,createdAt:new Date()});
 });
 await assertFails(setDoc(doc(db(host),'memberLocks',host),{pairCode:code,createdAt:serverTimestamp()}));
 await assertFails(setDoc(doc(db(partner),'memberLocks',partner),{pairCode:code,createdAt:serverTimestamp()}));
 await assertSucceeds(getDoc(doc(db(host),'pairInvites',code)));
 await assertSucceeds(getDoc(doc(db(partner),'pairInvites',code)));
});
test('pair owner cannot replace an existing lock with a different pairing',async()=>{
 const uid='lockedHost',code='LOCKEDPAIR01',d=db(uid);
 await env.withSecurityRulesDisabled(async c=>{
  const adminDb=c.firestore();
  await setDoc(doc(adminDb,'pairInvites',code),{hostUid:uid,partnerUid:null,activeRoom:null,openedBy:null,createdAt:new Date()});
  await setDoc(doc(adminDb,'memberLocks',uid),{pairCode:code,createdAt:new Date()});
 });
 await assertFails(updateDoc(doc(d,'memberLocks',uid),{pairCode:'OTHERPAIR999'}));
 await assertSucceeds(getDoc(doc(d,'memberLocks',uid)));
});
test('a third party cannot create a lock on another account',async()=>{
 await assertFails(setDoc(doc(db('outsider'),'memberLocks','existingHost'),{pairCode:'EXISTINGPAIR',createdAt:serverTimestamp()}));
});

test('ended rooms reject new ICE and late partner answers',async()=>{
 const code='ENDEDPAIR123',room='ENDED1';
 await env.withSecurityRulesDisabled(async c=>{
  const d=c.firestore();
  await setDoc(doc(d,'pairInvites',code),{hostUid:'endHost',partnerUid:'endPartner',activeRoom:room,openedBy:'endHost',createdAt:new Date()});
  await setDoc(doc(d,'rooms',room),{hostUid:'endHost',partnerUid:'endPartner',pairCode:code,createdAt:new Date(),expiresAt:Date.now()+3600000,active:false,endedAt:new Date(),offer:{type:'offer',sdp:'offer'}});
 });
 await assertFails(addDoc(collection(db('endHost'),'rooms',room,'hostCandidates'),{candidate:'candidate:late'}));
 await assertFails(addDoc(collection(db('endPartner'),'rooms',room,'partnerCandidates'),{candidate:'candidate:late'}));
 await assertFails(updateDoc(doc(db('endPartner'),'rooms',room),{answer:{type:'answer',sdp:'late'},partnerJoinedAt:serverTimestamp()}));
});
test('stale activeRoom cannot be replaced before cleanup',async()=>{
 const code='STALEPAIR123',oldRoom='STALE1',newRoom='STALE2';
 await env.withSecurityRulesDisabled(async c=>{
  const d=c.firestore();
  await setDoc(doc(d,'pairInvites',code),{hostUid:'staleHost',partnerUid:'stalePartner',activeRoom:oldRoom,openedBy:'staleHost',createdAt:new Date()});
  await setDoc(doc(d,'rooms',oldRoom),{hostUid:'staleHost',partnerUid:'stalePartner',pairCode:code,createdAt:new Date(),expiresAt:Date.now()-10000,active:true,offer:{type:'offer',sdp:'offer'}});
  await setDoc(doc(d,'rooms',newRoom),{hostUid:'staleHost',partnerUid:'stalePartner',pairCode:code,createdAt:new Date(),expiresAt:Date.now()+3600000,active:true,offer:{type:'offer',sdp:'offer'}});
 });
 await assertFails(updateDoc(doc(db('staleHost'),'pairInvites',code),{activeRoom:newRoom,openedBy:'staleHost'}));
 await assertSucceeds(updateDoc(doc(db('staleHost'),'pairInvites',code),{activeRoom:null,openedBy:null}));
});

test('orphaned active room cannot accept a partner answer',async()=>{
 const code='ORPHANPAIR12',room='ORPHAN';
 await env.withSecurityRulesDisabled(async c=>{
  const d=c.firestore();
  await setDoc(doc(d,'pairInvites',code),{hostUid:'orphanHost',partnerUid:'orphanPartner',activeRoom:null,openedBy:null,createdAt:new Date()});
  await setDoc(doc(d,'rooms',room),{hostUid:'orphanHost',partnerUid:'orphanPartner',pairCode:code,createdAt:new Date(),expiresAt:Date.now()+3600000,active:true,offer:{type:'offer',sdp:'offer'}});
 });
 await assertFails(updateDoc(doc(db('orphanPartner'),'rooms',room),{answer:{type:'answer',sdp:'answer'},partnerJoinedAt:serverTimestamp()}));
});
test('orphaned active room cannot accept ICE signaling',async()=>{
 const code='ORPHANPAIR12',room='ORPHAN';
 await assertFails(addDoc(collection(db('orphanHost'),'rooms',room,'hostCandidates'),{candidate:'candidate:orphan'}));
 await assertFails(addDoc(collection(db('orphanPartner'),'rooms',room,'partnerCandidates'),{candidate:'candidate:orphan'}));
});

test('registered room rejects malformed and oversized ICE payloads',async()=>{
 const code='PAYLOADPAIR1',room='PAYLOADROOM';
 await env.withSecurityRulesDisabled(async c=>{
  const d=c.firestore();
  await setDoc(doc(d,'pairInvites',code),{hostUid:'payloadHost',partnerUid:'payloadPartner',activeRoom:room,openedBy:'payloadHost',createdAt:new Date()});
  await setDoc(doc(d,'rooms',room),{hostUid:'payloadHost',partnerUid:'payloadPartner',pairCode:code,createdAt:new Date(),expiresAt:Date.now()+3600000,active:true,offer:{type:'offer',sdp:'offer'}});
 });
 await assertFails(addDoc(collection(db('payloadHost'),'rooms',room,'hostCandidates'),{candidate:'x'.repeat(8192)}));
 await assertFails(addDoc(collection(db('payloadHost'),'rooms',room,'hostCandidates'),{candidate:'candidate:ok',unexpected:'nope'}));
 await assertFails(addDoc(collection(db('payloadHost'),'rooms',room,'hostCandidates'),{candidate:123}));
 await assertSucceeds(addDoc(collection(db('payloadHost'),'rooms',room,'hostCandidates'),{candidate:'candidate:valid'}));
});
test('room creation rejects oversized or malformed offers',async()=>{
 const code='OFFERPAIR123';
 await env.withSecurityRulesDisabled(async c=>await setDoc(doc(c.firestore(),'pairInvites',code),{hostUid:'offerHost',partnerUid:'offerPartner',activeRoom:null,openedBy:null,createdAt:new Date()}));
 const base={hostUid:'offerHost',partnerUid:'offerPartner',pairCode:code,createdAt:serverTimestamp(),expiresAt:Date.now()+3600000,active:true};
 await assertFails(setDoc(doc(db('offerHost'),'rooms','BIG'),{...base,offer:{type:'offer',sdp:'x'.repeat(100000)}}));
 await assertFails(setDoc(doc(db('offerHost'),'rooms','WRONG'),{...base,offer:{type:'answer',sdp:'small'}}));
 await assertFails(setDoc(doc(db('offerHost'),'rooms','EXTRA'),{...base,offer:{type:'offer',sdp:'small'},unexpected:true}));
});

test('revoked pairing cannot create rooms, signal, answer, or change photos',async()=>{
 const code='REVOKEDEEP1',room='REVOKEROOM';
 await env.withSecurityRulesDisabled(async c=>{
  const d=c.firestore();
  await setDoc(doc(d,'pairInvites',code),{hostUid:'revHost',partnerUid:'revPartner',activeRoom:room,openedBy:'revHost',createdAt:new Date(),revoked:true,profilePhotos:{}});
  await setDoc(doc(d,'rooms',room),{hostUid:'revHost',partnerUid:'revPartner',pairCode:code,createdAt:new Date(),expiresAt:Date.now()+3600000,active:true,offer:{type:'offer',sdp:'offer'}});
 });
 await assertFails(getDoc(doc(db('revHost'),'pairInvites',code)));
 await assertFails(getDoc(doc(db('revPartner'),'rooms',room)));
 await assertFails(addDoc(collection(db('revHost'),'rooms',room,'hostCandidates'),{candidate:'candidate:revoked'}));
 await assertFails(addDoc(collection(db('revPartner'),'rooms',room,'partnerCandidates'),{candidate:'candidate:revoked'}));
 await assertFails(updateDoc(doc(db('revPartner'),'rooms',room),{answer:{type:'answer',sdp:'answer'},partnerJoinedAt:serverTimestamp()}));
 await assertFails(updateDoc(doc(db('revHost'),'pairInvites',code),{profilePhotos:{revHost:'data:image/jpeg;base64,QQ=='}}));
});
test('revoked pairing cannot be reopened or unrevoked',async()=>{
 const code='REVOKEDEEP2';
 await env.withSecurityRulesDisabled(async c=>await setDoc(doc(c.firestore(),'pairInvites',code),{hostUid:'rev2Host',partnerUid:'rev2Partner',activeRoom:null,openedBy:null,createdAt:new Date(),revoked:true}));
 await assertFails(updateDoc(doc(db('rev2Host'),'pairInvites',code),{activeRoom:'ANYROOM',openedBy:'rev2Host'}));
 await assertFails(updateDoc(doc(db('rev2Host'),'pairInvites',code),{revoked:false}));
});
