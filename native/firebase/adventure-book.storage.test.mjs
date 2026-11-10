import {test,before,after,beforeEach} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {initializeTestEnvironment,assertSucceeds,assertFails} from '@firebase/rules-unit-testing';
import {doc,setDoc,updateDoc} from 'firebase/firestore';
import {ref,uploadBytes,getBytes,getMetadata,deleteObject} from 'firebase/storage';
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
 console.log('REVOCATION phase=initial-upload');
 await assertSucceeds(uploadBytes(object('a','revocation-photo'),bytes,{contentType:'image/jpeg',customMetadata:{ownerUid:'a'}}));
 console.log('REVOCATION phase=admin-revoke');
 await env.withSecurityRulesDisabled(async c=>updateDoc(doc(c.firestore(),root+'pairInvites',code),{revoked:true}));
 console.log('REVOCATION phase=read-assert');
 try {
   await assert.rejects(async()=>getBytes(object('a','revocation-photo')),e=>e.code==='storage/unauthorized','revoked user must not download');
   console.log('REVOCATION read-assert=passed');
 } catch(e) {
   console.log('REVOCATION read-assert=failed code='+e?.code+' message='+e?.message);
   throw e;
 }
 console.log('REVOCATION phase=upload-assert');
 try {
   await assert.rejects(async()=>uploadBytes(object('a','later'),bytes,{contentType:'image/jpeg',customMetadata:{ownerUid:'a'}}),e=>e.code==='storage/unauthorized','revoked user must not upload');
   console.log('REVOCATION upload-assert=passed');
 } catch(e) {
   console.log('REVOCATION upload-assert=failed code='+e?.code+' message='+e?.message);
   throw e;
 }
});

test('interrupted upload retains immutable object; identical retry cannot overwrite',async()=>{
 const target=object('a','recovery-photo');
 const meta={contentType:'image/jpeg',customMetadata:{ownerUid:'a',sha256:'a'.repeat(64)}};
 const uploadResult=await assertSucceeds(uploadBytes(target,bytes,meta));
 assert.equal(uploadResult.metadata.size,bytes.byteLength);
 assert.equal(uploadResult.metadata.contentType,'image/jpeg');
 const stored=await assertSucceeds(getMetadata(object('b','recovery-photo')));
 assert.equal(stored.name,'recovery-photo');
 assert.equal(stored.size,bytes.byteLength);
 assert.equal(stored.contentType,'image/jpeg');
 assert.equal(stored.customMetadata.ownerUid,'a');
 assert.equal(stored.customMetadata.sha256,'a'.repeat(64));
 const saved=await assertSucceeds(getBytes(object('b','recovery-photo')));
 assert.equal(saved.byteLength,bytes.byteLength);
 assert.deepEqual(Array.from(new Uint8Array(saved)),Array.from(bytes));
 await assertFails(uploadBytes(target,bytes,meta));
 const unchanged=await assertSucceeds(getBytes(object('b','recovery-photo')));
 assert.equal(unchanged.byteLength,bytes.byteLength);
 assert.deepEqual(Array.from(new Uint8Array(unchanged)),Array.from(bytes));
 const after=await assertSucceeds(getMetadata(object('b','recovery-photo')));
 assert.equal(after.generation,stored.generation);
 assert.equal(after.size,stored.size);
 assert.equal(after.customMetadata.sha256,stored.customMetadata.sha256);
 await assertFails(deleteObject(target));
});
test('revoked user cannot recover remote object or delete orphan',async()=>{
 const target=object('a','orphan-photo');
 await assertSucceeds(uploadBytes(target,bytes,{contentType:'image/jpeg',customMetadata:{ownerUid:'a',sha256:'b'.repeat(64)}}));
 await env.withSecurityRulesDisabled(async c=>updateDoc(doc(c.firestore(),root+'pairInvites',code),{revoked:true}));
 await assertFails(getBytes(target));
 await assertFails(deleteObject(target));
 await assertFails(uploadBytes(target,bytes,{contentType:'image/jpeg',customMetadata:{ownerUid:'a'}}));
});
