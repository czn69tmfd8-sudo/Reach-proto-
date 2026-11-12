import {test,before,after,beforeEach} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {initializeTestEnvironment,assertSucceeds,assertFails} from '@firebase/rules-unit-testing';
import {doc,setDoc,getDoc,updateDoc,deleteDoc,collection,getDocs,query,limit,documentId,orderBy,startAfter,onSnapshot,serverTimestamp,writeBatch,runTransaction} from 'firebase/firestore';

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

test('Firestore transaction detects stale story version and preserves latest text',async()=>{
 const d=db('a'),ref=story(d);
 await assertSucceeds(setDoc(ref,{authorUid:'a',text:'Original',updatedAt:serverTimestamp()}));
 const initial=await getDoc(ref);
 const expected=initial.data().updatedAt.toMillis();
 const edit=(text)=>runTransaction(d,async transaction=>{
   const snap=await transaction.get(ref);
   if(snap.data().updatedAt.toMillis()!==expected) throw Error('adventure-story-version-conflict');
   transaction.update(ref,{text,updatedAt:serverTimestamp()});
 });
 const results=await Promise.allSettled([edit('First edit'),edit('Second edit')]);
 assert.equal(results.filter(r=>r.status==='fulfilled').length,1,'only one concurrent editor may commit');
 assert.equal(results.filter(r=>r.status==='rejected'&&r.reason.message==='adventure-story-version-conflict').length,1);
 const final=await getDoc(ref);
 assert.ok(['First edit','Second edit'].includes(final.data().text));
});

test('metadata publication after upload is immutable on create and survives duplicate retry',async()=>{
 const a=db('a'),b=db('b');
 const ref=photo(a,A,'trip','recovered-photo');
 const record={ownerUid:'a',storagePath:'adventureBook/'+A+'/trip/recovered-photo',caption:'',position:1,createdAt:serverTimestamp()};
 await assertSucceeds(setDoc(ref,record));
 const stored=await assertSucceeds(getDoc(photo(b,A,'trip','recovered-photo')));
 assert.equal(stored.data().ownerUid,'a');
 // A restarted client must read and adopt this exact record, not create
 // another owner or alter the original path.
 await assertFails(setDoc(ref,{...record,storagePath:'adventureBook/'+A+'/trip/different'}));
 await assertFails(setDoc(photo(b,A,'trip','recovered-photo'),{...record,ownerUid:'b'}));
 assert.equal((await getDoc(ref)).data().storagePath,record.storagePath);
 await assertFails(deleteDoc(ref));
});

test('paged listeners cover older memory edits, low-ID inserts and the story query limit', async () => {
 const host = db('a'), partner = db('b');
 await env.withSecurityRulesDisabled(async context => {
  const seedDB = context.firestore();
  const batch = writeBatch(seedDB);
  for (let index = 0; index < 100; index++) {
   const id = String(index).padStart(3, '0');
   batch.set(memory(seedDB, A, id), {...data(A), pageOrder:index});
  }
  await batch.commit();
 });

 const memories = collection(partner, 'adventureBooks', A, 'memories');
 const firstPage = query(memories, orderBy(documentId()), limit(50));
 const secondPage = query(memories, orderBy(documentId()), startAfter('049'), limit(50));
 await assertSucceeds(getDocs(query(collection(partner, 'adventureBooks', A, 'memories', '050', 'stories'), limit(2))));

 async function observeWrite(page, predicate, write) {
  let unsubscribe;
  let timer;
  try {
   let ready;
   const initial = new Promise(resolve => { ready = resolve; });
   const updated = new Promise((resolve, reject) => {
    timer = setTimeout(() => reject(Error('Timed out waiting for server snapshot')), 10000);
    unsubscribe = onSnapshot(page, {includeMetadataChanges:true}, snapshot => {
     if (snapshot.metadata.fromCache) return;
     ready();
     if (predicate(snapshot)) resolve();
    }, reject);
   });
   await Promise.all([updated, (async () => { await initial; await write(); })()]);
  } finally {
   clearTimeout(timer);
   unsubscribe?.();
  }
 }
 await observeWrite(secondPage,
  snapshot => snapshot.docs.some(item => item.id === '050' && item.data().title === 'Edited memory'),
  () => updateDoc(memory(host, A, '050'), {title:'Edited memory'}));
 await observeWrite(firstPage,
  snapshot => snapshot.docs.some(item => item.id === '000-new'),
  () => setDoc(memory(host, A, '000-new'), {...data(A), createdAt:serverTimestamp()}));
});

test('comment retries adopt the original immutable operation and reject a different payload', async () => {
 const host = db('a'), partner = db('b');
 const id = 'stable-comment-operation';
 const ref = comment(host, A, 'trip', id);
 const submit = text => runTransaction(host, async transaction => {
  const existing = await transaction.get(ref);
  if (existing.exists()) {
   if (existing.data().authorUid !== 'a' || existing.data().text !== text) {
    throw Error('comment-operation-conflict');
   }
   return;
  }
  transaction.set(ref, {authorUid:'a', text, createdAt:serverTimestamp()});
 });
 await assertSucceeds(submit('One comment'));
 const original = (await getDoc(ref)).data();
 await assertSucceeds(submit('One comment'));
 await assert.rejects(submit('Different payload'), /comment-operation-conflict/);
 assert.deepEqual((await getDoc(comment(partner, A, 'trip', id))).data(), original);
 const conversation = await getDocs(query(collection(partner, 'adventureBooks', A, 'memories', 'trip', 'comments'), limit(50)));
 assert.equal(conversation.size, 1);
});

test('gallery cover query sees a photo reorder between hydration and listener attachment', async () => {
 const host = db('a'), partner = db('b');
 for (const [id, position] of [['p1', 1], ['p2', 2]]) {
  await assertSucceeds(setDoc(photo(host, A, 'trip', id), {
   ownerUid:'a', storagePath:'adventureBook/'+A+'/trip/'+id, caption:'', position, createdAt:serverTimestamp()
  }));
 }
 const cover = query(collection(partner, 'adventureBooks', A, 'memories', 'trip', 'photos'),
  orderBy('position'), orderBy(documentId()), limit(1));
 assert.equal((await getDocs(cover)).docs[0].id, 'p1');
 await assertSucceeds(updateDoc(photo(host, A, 'trip', 'p2'), {position:0}));

 let unsubscribe;
 let timer;
 try {
  const snapshot = await new Promise((resolve, reject) => {
   timer = setTimeout(() => reject(Error('Timed out waiting for the first server snapshot')), 10000);
   unsubscribe = onSnapshot(cover, {includeMetadataChanges:true}, result => {
    if (!result.metadata.fromCache) resolve(result);
   }, reject);
  });
  assert.equal(snapshot.docs[0].id, 'p2');
 } finally {
  clearTimeout(timer);
  unsubscribe?.();
 }
});

test('an interrupted initial story resumes against the same memory without replacing a later edit', async () => {
 const host = db('a'), partner = db('b');
 const id = 'pending-memory';
 const ref = memory(host, A, id);
 const initialStory = story(host, A, id);
 const draft = {...data(A), title:'Our first page', pageOrder:1};
 const saveMemory = () => runTransaction(host, async transaction => {
  const existing = await transaction.get(ref);
  if (existing.exists()) {
   assert.equal(existing.data().title, draft.title);
   assert.equal(existing.data().creatorUid, draft.creatorUid);
   assert.equal(existing.data().pageOrder, draft.pageOrder);
   return;
  }
  transaction.set(ref, {...draft, createdAt:serverTimestamp()});
 });
 const saveInitialStory = text => runTransaction(host, async transaction => {
  const existing = await transaction.get(initialStory);
  if (existing.exists()) {
   if (existing.data().authorUid !== 'a' || existing.data().text !== text) throw Error('story-conflict');
   return;
  }
  transaction.set(initialStory, {authorUid:'a', text, updatedAt:serverTimestamp()});
 });
 await assertFails(saveInitialStory('The first story'));
 await assertSucceeds(saveMemory());
 const original = (await getDoc(ref)).data();
 await assertSucceeds(saveMemory());
 await assertSucceeds(saveInitialStory('The first story'));
 await assertSucceeds(saveInitialStory('The first story'));
 assert.deepEqual((await getDoc(memory(partner, A, id))).data(), original);

 await assertSucceeds(updateDoc(initialStory, {text:'Edited later', updatedAt:serverTimestamp()}));
 await assert.rejects(saveInitialStory('The first story'), /story-conflict/);
 assert.equal((await getDoc(story(partner, A, id))).data().text, 'Edited later');
});

test('current rules permit concurrent creates to exceed the client-only memory limit', async () => {
 await env.withSecurityRulesDisabled(async context => {
  const d = context.firestore();
  const batch = writeBatch(d);
  for (let i = 0; i < 498; i++) batch.set(memory(d, A, 'existing-'+i), {...data(A), pageOrder:i+1});
  await batch.commit();
 });
 const a = db('a'), b = db('b');
 await Promise.all([
  assertSucceeds(setDoc(memory(a, A, 'final-a'), {...data(A), pageOrder:499, createdAt:serverTimestamp()})),
  assertSucceeds(setDoc(memory(b, A, 'final-b'), {...data(A), creatorUid:'b', pageOrder:499, createdAt:serverTimestamp()}))
 ]);
 await env.withSecurityRulesDisabled(async context => {
  const all = await getDocs(collection(context.firestore(), 'adventureBooks', A, 'memories'));
  assert.equal(all.size, 501);
 });
});
