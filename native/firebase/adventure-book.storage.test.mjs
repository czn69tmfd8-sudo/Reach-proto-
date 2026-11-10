import {test,before,after,beforeEach} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {initializeTestEnvironment,assertSucceeds,assertFails} from '@firebase/rules-unit-testing';
import {doc,setDoc,updateDoc} from 'firebase/firestore';
import {ref,uploadBytes,getBytes,deleteObject} from 'firebase/storage';
let env;
const code='ABCDEFGHJKLM';
const root='nativeStaging/v1/';
const storage=u=>u?env.authenticatedContext(u).storage():env.unauthenticatedContext().storage();
const object=(u,id='p1')=>ref(storage(u),'adventureBook/'+code+'/trip/'+id);
const bytes=new Uint8Array([0xff,0xd8,0xff,0xd9]);
before(async()=>{
 env=await initializeTestEnvironment({projectId:'demo-reach-adventure',firestore:{rules:await readFile('adventure-book.combined.generated.rules','utf8')},storage:{rules:await readFile('adventure-book.storage.proposed.rules','utf8')}});
});
beforeEach(async()=>{
 await env.clearFirestore();await env.clearStorage();
 await env.withSecurityRulesDisabled(async c=>{
  const d=c.firestore();
  await setDoc(doc(d,root+'pairInvites',code),{hostUid:'a',partnerUid:'b',revoked:false});
  for(const u of ['a','b']) await setDoc(doc(d,root+'memberLocks',u),{pairCode:code});
  await setDoc(doc(d,'adventureBooks',code,'memories','trip'),{pairCode:code,creatorUid:'a',title:'Trip',occurredAt:new Date(),createdAt:new Date(),pageOrder:0});
 });
});
after(async()=>env?.cleanup());
test('authorized owner uploads immutable jpeg; partner reads, outsiders denied',async()=>{
 await assertSucceeds(uploadBytes(object('a'),bytes,{contentType:'image/jpeg',customMetadata:{ownerUid:'a'}}));
 await assertSucceeds(getBytes(object('b')));
 await assertFails(getBytes(object('c')));
 await assertFails(getBytes(object()));
 await assertFails(uploadBytes(object('b'),bytes,{contentType:'image/jpeg',customMetadata:{ownerUid:'b'}}));
 await assertFails(deleteObject(object('b')));
});
test('reject forged owner, oversized upload and wrong content type',async()=>{
 await assertFails(uploadBytes(object('b','forged'),bytes,{contentType:'image/jpeg',customMetadata:{ownerUid:'a'}}));
 await assertFails(uploadBytes(object('a','text'),bytes,{contentType:'text/plain',customMetadata:{ownerUid:'a'}}));
 await assertFails(uploadBytes(object('a','large'),new Uint8Array(15728641),{contentType:'image/jpeg',customMetadata:{ownerUid:'a'}}));
});
test('revocation blocks authenticated SDK reads and writes without deleting stored bytes',async()=>{
 await assertSucceeds(uploadBytes(object('a'),bytes,{contentType:'image/jpeg',customMetadata:{ownerUid:'a'}}));
 await env.withSecurityRulesDisabled(async c=>updateDoc(doc(c.firestore(),root+'pairInvites',code),{revoked:true}));
 await assert.rejects(async()=>getBytes(object('a')),e=>e.code==='storage/unauthorized','revoked user must not download');
 await assert.rejects(async()=>uploadBytes(object('a','later'),bytes,{contentType:'image/jpeg',customMetadata:{ownerUid:'a'}}),e=>e.code==='storage/unauthorized','revoked user must not upload');
});
