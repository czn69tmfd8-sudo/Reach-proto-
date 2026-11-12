import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createMockUserToken } from '@firebase/util';
import { after, before, beforeEach, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { Bytes, collection, deleteDoc, doc, getDocFromServer, getDocsFromServer, runTransaction, serverTimestamp, setDoc, updateDoc } from 'firebase/firestore';

// Emulator-only fixture. No bucket, public URLs, or app data are used.
const imageRules = `
  match /privatePhotoPreviews/preview {
    allow get: if adventureAuthorized(code)
      && exists(/databases/$(database)/documents/adventureBooks/$(code)/memories/$(memoryID));
    allow create: if adventureAuthorized(code)
      && exists(/databases/$(database)/documents/adventureBooks/$(code)/memories/$(memoryID))
      && request.resource.data.keys().hasOnly(['ownerUid', 'operationID', 'bytes', 'createdAt'])
      && request.resource.data.ownerUid == request.auth.uid
      && request.resource.data.operationID is string
      && request.resource.data.operationID.matches('[A-Za-z0-9_-]{1,128}')
      && request.resource.data.bytes is bytes
      && request.resource.data.bytes.size() > 0
      && request.resource.data.bytes.size() <= 262144
      && request.resource.data.createdAt == request.time;
  }
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

const preview = d => doc(memory(d), 'privatePhotoPreviews', 'preview');

// Node's emulator client uses in-memory SDK state. Read paths require a
// server response; callers never fall back to a locally available payload.
function publishPreview(d, ownerUid, operationID, bytes) {
  const ref = preview(d);
  return runTransaction(d, async transaction => {
    const existing = await transaction.get(ref);
    if (existing.exists()) {
      const data = existing.data();
      if (data.ownerUid !== ownerUid || data.operationID !== operationID || !data.bytes.isEqual(bytes)) {
        throw Error('photo-conflict');
      }
      return;
    }
    transaction.set(ref, { ownerUid, operationID, bytes, createdAt: serverTimestamp() });
  });
}

test('one immutable preview per memory keeps metadata and bytes together across retries', async () => {
  const a = db('a'), b = db('b');
  const bytes = image('a').bytes;
  await assertSucceeds(publishPreview(a, 'a', 'stable-operation', bytes));
  const original = (await getDocFromServer(preview(b))).data();
  await assertSucceeds(publishPreview(a, 'a', 'stable-operation', bytes));
  assert.deepEqual((await getDocFromServer(preview(b))).data(), original);
  await assert.rejects(publishPreview(a, 'a', 'stable-operation', image('a', 17).bytes), /photo-conflict/);
  await assert.rejects(publishPreview(b, 'b', 'other-operation', bytes), /photo-conflict/);
  await assertFails(setDoc(doc(memory(a), 'privatePhotoPreviews', 'second-slot'), {
    ...image('a'), operationID: 'another-slot',
  }));
  await assertFails(getDocsFromServer(collection(memory(b), 'privatePhotoPreviews')));
  await assertFails(getDocFromServer(preview(db('c'))));

  await env.withSecurityRulesDisabled(async context => {
    await updateDoc(doc(context.firestore(), root, 'pairInvites', A), { revoked: true });
  });
  await assertFails(getDocFromServer(preview(b)));
  await assertFails(publishPreview(a, 'a', 'stable-operation', bytes));
});

test('native REST shape is create-only and eight visible reads fail closed after revocation', async () => {
  const project = 'demo-reach-adventure';
  const host = process.env.FIRESTORE_EMULATOR_HOST;
  assert.match(host ?? '', /^(127\.0\.0\.1|localhost):\d+$/);
  const base = 'projects/' + project + '/databases/(default)/documents';
  const slot = id => base + '/adventureBooks/' + A + '/memories/' + id + '/privatePhotoPreviews/preview';
  const headers = uid => ({
    Authorization: 'Bearer ' + createMockUserToken({ sub: uid }, project),
    'Content-Type': 'application/json',
    'Cache-Control': 'no-store',
  });
  async function request(path, uid, body) {
    const response = await fetch('http://' + host + '/v1/' + path, {
      method: body ? 'POST' : 'GET',
      headers: headers(uid),
      body: body ? JSON.stringify(body) : undefined,
    });
    const data = await response.json();
    return { status: response.status, data };
  }
  function commit(id, bytes) {
    return request(base + ':commit', 'a', { writes: [{
      update: { name: slot(id), fields: {
        ownerUid: { stringValue: 'a' },
        operationID: { stringValue: 'test-operation' },
        bytes: { bytesValue: bytes },
      } },
      updateTransforms: [{ fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' }],
      currentDocument: { exists: false },
    }] });
  }
  const ids = Array.from({ length: 8 }, (_, index) => 'card-' + index);
  await env.withSecurityRulesDisabled(async context => {
    const d = context.firestore();
    for (const id of ids) await setDoc(memory(d, A, id), {
      pairCode: A, creatorUid: 'a', title: 'Synthetic card', occurredAt: new Date(0),
      pageOrder: 0, createdAt: serverTimestamp(),
    });
  });
  for (const id of ids) {
    const result = await commit(id, '/9j/4AEA');
    assert.equal(result.status, 200, JSON.stringify(result.data));
  }
  const retry = await commit(ids[0], '/9j/4AEB');
  assert.ok([400, 403, 409].includes(retry.status), JSON.stringify(retry.data));
  const spread = await Promise.all(ids.map(id => request(slot(id), 'b')));
  assert.equal(spread.length, 8);
  assert.ok(spread.every(result => result.status === 200));
  assert.equal(spread[0].data.fields.bytes.bytesValue, '/9j/4AEA');
  assert.equal((await request(slot(ids[0]), 'c')).status, 403);
  await env.withSecurityRulesDisabled(async context => {
    await updateDoc(doc(context.firestore(), root, 'pairInvites', A), { revoked: true });
  });
  assert.equal((await request(slot(ids[0]), 'b')).status, 403);
  assert.equal((await commit(ids[0], '/9j/4AEA')).status, 403);
});
