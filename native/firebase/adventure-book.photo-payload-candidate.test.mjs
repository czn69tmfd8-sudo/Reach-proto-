import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { after, before, beforeEach, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { Bytes, collection, deleteDoc, doc, getDocFromServer, getDocsFromServer, serverTimestamp, setDoc, updateDoc } from 'firebase/firestore';

// Emulator-only fixture. No bucket, public URLs, or app data are used.
const imageRules = `
  match /photoPayloads/{photoID} {
    allow get: if adventureAuthorized(code)
      && exists(/databases/$(database)/documents/adventureBooks/$(code)/memories/$(memoryID));
    allow create: if adventureAuthorized(code)
      && exists(/databases/$(database)/documents/adventureBooks/$(code)/memories/$(memoryID))
      && photoID.matches('[A-Za-z0-9_-]{1,128}')
      && request.resource.data.keys().hasOnly(['ownerUid', 'bytes', 'createdAt'])
      && request.resource.data.ownerUid == request.auth.uid
      && request.resource.data.bytes is bytes
      && request.resource.data.bytes.size() > 0
      && request.resource.data.bytes.size() <= 262144
      && request.resource.data.createdAt == request.time;
  }
`;
const A = 'ABCDEFGHJKLM', B = 'NPQRSTUVWXYZ';
const root = 'nativeStaging/v1';
const cap = 262144;
let env;
const db = uid => uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore();
const memory = (d, code = A, id = 'trip') => doc(d, 'adventureBooks', code, 'memories', id);
const payload = (d, id = 'image', code = A, memoryID = 'trip') =>
  doc(memory(d, code, memoryID), 'photoPayloads', id);
const image = (uid, size = 16) => ({
  ownerUid: uid, bytes: Bytes.fromUint8Array(new Uint8Array(size).fill(7)), createdAt: serverTimestamp(),
});

before(async () => {
  const base = await readFile('adventure-book.combined.generated.rules', 'utf8');
  const marker = 'match /adventureBooks/{code}/memories/{memoryID} {';
  assert.equal(base.split(marker).length, 2);
  const rules = base.replace(marker, marker + '\n' + imageRules);
  env = await initializeTestEnvironment({ projectId: 'demo-reach-adventure', firestore: { rules } });
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async context => {
    const d = context.firestore();
    for (const [code, host, partner] of [[A, 'a', 'b'], [B, 'c', 'd']]) {
      await setDoc(doc(d, root, 'pairInvites', code), { hostUid: host, partnerUid: partner, revoked: false });
      await setDoc(doc(d, root, 'memberLocks', host), { pairCode: code });
      await setDoc(doc(d, root, 'memberLocks', partner), { pairCode: code });
      await setDoc(memory(d, code), {
        pairCode: code, creatorUid: host, title: 'Synthetic memory', occurredAt: new Date(0),
        pageOrder: 0, createdAt: serverTimestamp(),
      });
    }
  });
});

after(async () => env?.cleanup());

test('both members can retrieve private bytes by ID while guests and other couples are denied', async () => {
  await assertSucceeds(setDoc(payload(db('a')), image('a')));
  for (const uid of ['a', 'b']) {
    const data = (await assertSucceeds(getDocFromServer(payload(db(uid))))).data();
    assert.deepEqual(data.bytes.toUint8Array(), new Uint8Array(16).fill(7));
    assert.deepEqual(Object.keys(data).sort(), ['bytes', 'createdAt', 'ownerUid']);
  }
  for (const uid of [undefined, 'c', 'd']) {
    await assertFails(getDocFromServer(payload(db(uid))));
    await assertFails(setDoc(payload(db(uid), 'unrelated'), image(uid ?? 'guest')));
  }
  await assertFails(getDocsFromServer(collection(memory(db('a')), 'photoPayloads')));
});

test('image writes require an existing memory, exact ownership, bounded bytes and immutable IDs', async () => {
  const a = db('a');
  await assertSucceeds(setDoc(payload(a, 'boundary'), image('a', cap)));
  await assertFails(setDoc(payload(a, 'oversize'), image('a', cap + 1)));
  await assertFails(setDoc(payload(a, 'empty'), image('a', 0)));
  await assertFails(setDoc(payload(a, 'spoofed'), image('b')));
  await assertFails(setDoc(payload(a, 'url'), { ...image('a'), url: 'https://example.invalid/public' }));
  await assertFails(setDoc(payload(a, 'string'), { ...image('a'), bytes: 'not-bytes' }));
  await assertFails(setDoc(payload(a, 'orphan', A, 'missing'), image('a')));
  await assertFails(setDoc(payload(a, 'boundary'), image('a')));
  await assertFails(deleteDoc(payload(a, 'boundary')));
});

test('a changed lock or pair revocation denies subsequent server reads and writes', async () => {
  const a = db('a'), b = db('b');
  await assertSucceeds(setDoc(payload(a), image('a')));
  await assertSucceeds(getDocFromServer(payload(b)));
  await env.withSecurityRulesDisabled(async context => {
    await updateDoc(doc(context.firestore(), root, 'memberLocks', 'b'), { pairCode: B });
  });
  await assertFails(getDocFromServer(payload(a)));
  await assertFails(getDocFromServer(payload(b)));
  await assertFails(setDoc(payload(a, 'lock-changed'), image('a')));
  await env.withSecurityRulesDisabled(async context => {
    const d = context.firestore();
    await updateDoc(doc(d, root, 'memberLocks', 'b'), { pairCode: A });
    await updateDoc(doc(d, root, 'pairInvites', A), { revoked: true });
  });
  await assertFails(getDocFromServer(payload(a)));
  await assertFails(getDocFromServer(payload(b)));
  await assertFails(setDoc(payload(b, 'revoked'), image('b')));
});
