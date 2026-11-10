import {test,before,after,beforeEach} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {initializeTestEnvironment,assertSucceeds,assertFails} from '@firebase/rules-unit-testing';
import {doc,setDoc,getDoc,updateDoc,deleteDoc,collection,getDocs,query,limit,serverTimestamp,writeBatch} from 'firebase/firestore';

let env;
const A='ABCDEFGHJKLM', B='NPQRSTUVWXYZ';
const root='nativeStaging/v1/';
const db=u=>u?env.authenticatedContext(u).firestore():env.unauthenticatedContext().firestore();
const memory=(d,c=A,id='trip')=>doc(d,'adventureBooks',c,'memories',id);
const story=(d,c=A,id='trip',uid='a')=>doc(d,'adventureBooks',c,'memories',id,'stories',uid);
const comment=(d,c=A,id='trip',id2='c1')=>doc(d,'adventureBooks',c,'memories',id,'comments',id2);
const photo=(d,c=A,id='trip',id2='p1')=>doc(d,'adventureBooks',c,'memories',id,'photos',id2);
const data=c=>({pairCode:c,creatorUid:c===A?'a':'c',title:'Our trip',occurredAt:new Date(),pageOrder:0,createdAt:new Date()});
const storyData=u=>({authorUid:u,text:'My story',updatedAt:new Date()});
async function seed(){
 await env.withSecurityRulesDisabled(async c=>{
  const d=c.firestore();
  for(const [code,host,partner] of [[A,'a','b'],[B,'c','d']]){
   await setDoc(doc(d,root+'pairInvites',code),{hostUid:host,partnerUid:partner,revoked:false});
   for(const uid of [host,partner])await setDoc(doc(d,root+'memberLocks',uid),{pairCode:code});
   await setDoc(memory(d,code),data(code));
  }
 });
}
before(async()=>{
 const rules=await readFile('adventure-book.combined.generated.rules','utf8');
 env=await initializeTestEnvironment({projectId:'demo-reach-adventure',firestore:{rules}});
});
beforeEach(async()=>{await env.clearFirestore();await seed()});
after(async()=>env?.cleanup());

test('cross-couple and anonymous reads are denied across all collections',async()=>{
 const d=db('c'),guest=db();
 for(const ref of [memory(d),story(d),comment(d),photo(d)]){
  await assertFails(getDoc(ref));
 }
 await assertFails(getDoc(memory(guest)));
 await assertFails(getDocs(query(collection(d,'adventureBooks',A,'memories'),limit(20))));
 await assertSucceeds(getDoc(memory(db('a'))));
 await assertSucceeds(getDoc(memory(db('b'))));
});

test('both partners own only their own story, and cannot replace another',async()=>{
 const a=db('a'),b=db('b'),c=db('c');
 await assertSucceeds(setDoc(story(a),{authorUid:'a',text:'A',updatedAt:serverTimestamp()}));
 await assertSucceeds(setDoc(story(b,A,'trip','b'),{authorUid:'b',text:'B',updatedAt:serverTimestamp()}));
 await assertFails(updateDoc(story(b),{text:'stolen',updatedAt:serverTimestamp()}));
 await assertFails(setDoc(story(c),{authorUid:'a',text:'stolen',updatedAt:serverTimestamp()}));
 await assertSucceeds(updateDoc(story(a),{text:'A revised',updatedAt:serverTimestamp()}));
 assert.equal((await getDoc(story(b,A,'trip','b'))).data().text,'B');
 await assertFails(deleteDoc(story(a)));
});

test('comments and photo metadata require member authorization and immutable ownership',async()=>{
 const a=db('a'),b=db('b'),c=db('c');
 await assertSucceeds(setDoc(comment(a),{authorUid:'a',text:'Hello',createdAt:serverTimestamp()}));
 await assertFails(setDoc(comment(c,A,'trip','c2'),{authorUid:'c',text:'No',createdAt:serverTimestamp()}));
 await assertFails(updateDoc(comment(a),{text:'replaced'}));
 await assertSucceeds(setDoc(photo(a),{ownerUid:'a',storagePath:'adventureBook/'+A+'/trip/p1',caption:'',position:0,createdAt:serverTimestamp()}));
 await assertFails(setDoc(photo(b,A,'trip','p2'),{ownerUid:'a',storagePath:'adventureBook/'+A+'/trip/p2',caption:'',position:0,createdAt:serverTimestamp()}));
 await assertFails(setDoc(photo(a,A,'trip','p3'),{ownerUid:'a',storagePath:'adventureBook/'+B+'/trip/p3',caption:'',position:0,createdAt:serverTimestamp()}));
 await assertFails(updateDoc(photo(b),{caption:'not mine'}));
 await assertSucceeds(updateDoc(photo(a),{caption:'Our view'}));
 await assertFails(deleteDoc(photo(a)));
});

test('revocation denies access without deleting existing content',async()=>{
 const a=db('a');
 await assertSucceeds(setDoc(story(a),{authorUid:'a',text:'Keep',updatedAt:serverTimestamp()}));
 await env.withSecurityRulesDisabled(async c=>updateDoc(doc(c.firestore(),root+'pairInvites',A),{revoked:true}));
 await assertFails(getDoc(memory(a)));
 await assertFails(getDoc(story(a)));
 await assertFails(setDoc(comment(a,A,'trip','c2'),{authorUid:'a',text:'No',createdAt:serverTimestamp()}));
 await env.withSecurityRulesDisabled(async c=>{
  assert.equal((await getDoc(story(c.firestore()))).data().text,'Keep');
 });
});

test('missing and mismatched member locks deny access',async()=>{
 const a=db('a');
 await env.withSecurityRulesDisabled(async c=>deleteDoc(doc(c.firestore(),root+'memberLocks','b')));
 await assertFails(getDoc(memory(a)));
 await env.withSecurityRulesDisabled(async c=>setDoc(doc(c.firestore(),root+'memberLocks','b'),{pairCode:B}));
 await assertFails(getDoc(memory(a)));
});

test('missing partner and expired invitation are not treated as active membership',async()=>{
 const a=db('a');
 await env.withSecurityRulesDisabled(async c=>updateDoc(doc(c.firestore(),root+'pairInvites',A),{partnerUid:null,expiresAt:0}));
 await assertFails(getDoc(memory(a)));
});

test('independent story documents remain intact after another authorized edit',async()=>{
 const a=db('a');
 await assertSucceeds(setDoc(story(a),{authorUid:'a',text:'First',updatedAt:serverTimestamp()}));
 const first=await getDoc(story(a));
 const version=first.data().updatedAt;
 // This does not validate compare-and-swap. Real server updateTime preconditions
 // and concurrent stale-write rejection require separate integration coverage.
 await assertSucceeds(updateDoc(story(a),{text:'Second',updatedAt:serverTimestamp()}));
 assert.equal((await getDoc(story(a))).data().text,'Second');
 assert.ok(version);
});
