const {before,after,test}=require('node:test');
const assert=require('node:assert/strict');
const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {doc,setDoc,getDoc,updateDoc,collection,addDoc,getDocs}=require('firebase/firestore');
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
