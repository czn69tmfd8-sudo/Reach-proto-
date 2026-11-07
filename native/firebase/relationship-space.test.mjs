// Local emulator only. Tests the exact additive candidate by default.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { after, before, beforeEach, test } from 'node:test';
import { createMockUserToken } from '@firebase/util';
import { readRelationshipReview } from './prepare-rules-review.mjs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { Bytes, Timestamp, collection, deleteDoc, doc, getDoc, getDocs, limit, query, serverTimestamp, setDoc, updateDoc, writeBatch } from 'firebase/firestore';

let env;
const project = 'demo-reach-relationship-space';
const code = 'ABCDEFGHJKLM';
const nextCode = 'NPQRSTUVWXYZ';
const pair = code => `nativeStaging/v1/pairInvites/${code}`;
const lock = uid => `nativeStaging/v1/memberLocks/${uid}`;
const pilot = code => `nativeStaging/v1/relationshipSpace/${code}`;
const entries = code => pilot(code) + '/entries';
const db = uid => (uid ? env.authenticatedContext(uid) : env.unauthenticatedContext()).firestore();
const id = index => `12345678-1234-1234-1234-${String(index).padStart(12, '0')}`;
const entry = (uid, index = 1, scope = code) => doc(db(uid), entries(scope), id(index));
const data = (patch = {}) => ({
  kind: 'memory', authorUid: 'a', title: 'A morning together', caption: 'Scrapbook',
  eventAt: Timestamp.fromMillis(0), progress: 0, ...patch,
});
async function seed(records) {
  await env.withSecurityRulesDisabled(async context => {
    const admin = context.firestore();
    const batch = writeBatch(admin);
    for (const [path, value] of records) batch.set(doc(admin, path), value);
    await batch.commit();
  });
}
before(async () => {
  assert.match(process.env.FIRESTORE_EMULATOR_HOST ?? '', /^(127\.0\.0\.1|localhost):\d+$/);
  const rules = process.env.REACH_SHARED_STANDALONE === '1'
    ? await readFile(new URL('../sync-proposal/relationship-space.proposed.rules', import.meta.url), 'utf8')
    : await readRelationshipReview();
  env = await initializeTestEnvironment({ projectId: project, firestore: { rules } });
});
beforeEach(async () => {
  await env.clearFirestore();
  await seed([[pair(code), {hostUid: 'a', partnerUid: 'b', revoked: false}], [lock('a'), {pairCode: code}], [lock('b'), {pairCode: code}], [pilot(code), {enabled: true}]]);
});
after(async () => env?.cleanup());

test('both partners can sync and read the same shared entry and its photo', async () => {
  const photo = Bytes.fromUint8Array(new Uint8Array(250000));
  await assertSucceeds(setDoc(entry('a'), data({photo})));
  const snapshot = await assertSucceeds(getDoc(entry('b')));
  assert(snapshot.data().photo.isEqual(photo));
  await assertSucceeds(getDocs(query(collection(db('b'), entries(code)), limit(12))));
  await assertFails(getDocs(collection(db('b'), entries(code))));
  await assertFails(getDocs(query(collection(db('b'), entries(code)), limit(13))));
  for (const uid of [null, 'outsider']) {
    await assertFails(getDoc(entry(uid)));
    await assertFails(getDocs(query(collection(db(uid), entries(code)), limit(12))));
  }
});

test('only the author edits or deletes; their partner sees updates and deletions', async () => {
  await assertSucceeds(setDoc(entry('a'), data()));
  await assertFails(updateDoc(entry('b'), {caption: 'overwrite'}));
  await assertFails(updateDoc(entry('a'), {authorUid: 'b'}));
  await assertFails(updateDoc(entry('a'), {kind: 'plan'}));
  await assertFails(deleteDoc(entry('b')));
  await assertSucceeds(updateDoc(entry('a'), {caption: 'edited'}));
  assert.equal((await getDoc(entry('b'))).data().caption, 'edited');
  await assertSucceeds(deleteDoc(entry('a')));
  assert.equal((await getDoc(entry('b'))).exists(), false);
});

test('a broken lock, revocation and re-pairing all deny access to the old space', async () => {
  await assertSucceeds(setDoc(entry('a'), data()));
  await seed([[lock('b'), {pairCode: nextCode}]]);
  await assertFails(getDoc(entry('a')));
  await assertFails(setDoc(entry('a', 2), data()));
  await seed([[lock('b'), {pairCode: code}], [pair(code), {hostUid: 'a', partnerUid: 'b', revoked: true}]]);
  for (const uid of ['a', 'b']) await assertFails(getDoc(entry(uid)));
  await assertFails(deleteDoc(entry('a')));
  await seed([[pair(nextCode), {hostUid: 'a', partnerUid: 'c', revoked: false}], [lock('a'), {pairCode: nextCode}], [lock('c'), {pairCode: nextCode}], [pilot(nextCode), {enabled: true}]]);
  await assertSucceeds(setDoc(entry('a', 1, nextCode), data({title: 'A different entry'})));
  await assertFails(getDoc(entry('b', 1, nextCode)));
  assert.equal((await getDoc(entry('c', 1, nextCode))).data().title, 'A different entry');
  await assertFails(getDoc(entry('c')));
});

test('schema rejects forged authorship, private fields, oversized photos, and invalid progress', async () => {
  for (const patch of [
    {authorUid: 'b'}, {privateNotes: 'secret'}, {caption: 'x'.repeat(6001)}, {title: ''},
    {kind: 'goal', progress: 101}, {progress: 5}, {photo: 'external-photo'},
    {photo: Bytes.fromUint8Array(new Uint8Array(250001))},
    {kind: 'plan', photo: Bytes.fromUint8Array(new Uint8Array([1]))},
  ]) await assertFails(setDoc(entry('a'), data(patch)));
  for (const kind of ['milestone', 'goal', 'response', 'plan']) {
    await assertSucceeds(setDoc(entry('a', ['milestone', 'goal', 'response', 'plan'].indexOf(kind) + 10),
      data({kind, progress: kind === 'goal' ? 40 : 0})));
  }
});

test('pilot control is admin-only and disabling it denies both partners', async () => {
  await assertSucceeds(setDoc(entry('a'), data()));
  for (const uid of ['a', 'b']) {
    await assertFails(getDoc(doc(db(uid), pilot(code))));
    await assertFails(setDoc(doc(db(uid), pilot(code)), {enabled: false}));
    await assertFails(deleteDoc(doc(db(uid), pilot(code))));
  }
  await seed([[pilot(code), {enabled: false}]]);
  for (const uid of ['a', 'b']) {
    await assertFails(getDoc(entry(uid)));
    await assertFails(getDocs(query(collection(db(uid), entries(code)), limit(12))));
  }
  await assertFails(updateDoc(entry('a'), {caption: 'late edit'}));
  await assertFails(deleteDoc(entry('a')));
});

test('expired unaccepted invitations deny sharing; accepted pairs outlive their invitation', async () => {
  await assertSucceeds(setDoc(entry('a'), data()));
  await seed([[pair(code), {hostUid: 'a', partnerUid: null, revoked: false, expiresAt: 1}]]);
  for (const uid of ['a', 'b']) await assertFails(getDoc(entry(uid)));
  await assertFails(setDoc(entry('a', 2), data()));
  if (process.env.REACH_SHARED_STANDALONE !== '1') {
    await env.withSecurityRulesDisabled(context => deleteDoc(doc(context.firestore(), lock('b'))));
    const joining = db('b');
    const join = writeBatch(joining);
    join.update(doc(joining, pair(code)), {partnerUid: 'b'});
    join.set(doc(joining, lock('b')), {pairCode: code, createdAt: serverTimestamp()});
    await assertFails(join.commit());
  }
  await seed([[pair(code), {hostUid: 'a', partnerUid: 'b', revoked: false, expiresAt: 1}], [lock('b'), {pairCode: code}]]);
  for (const uid of ['a', 'b']) await assertSucceeds(getDoc(entry(uid)));
});

test('sharing grants no outsider access to legacy paths', async () => {
  const uid = process.env.REACH_SHARED_STANDALONE === '1' ? 'a' : null;
  for (const path of [pair(code), lock('a'), 'nativeStaging/v1/rooms/room', 'pairInvites/legacy']) {
    await assertFails(getDoc(doc(db(uid), path)));
    await assertFails(setDoc(doc(db(uid), path), {}));
  }
});

test('REST sync uses scoped queries and rejects a stale edit or duplicate create', async () => {
  const host = process.env.FIRESTORE_EMULATOR_HOST;
  const root = `http://${host}/v1/projects/${project}/databases/(default)/documents/`;
  const path = entries(code) + '/' + id(1);
  const call = (uid, resource, method, body) => fetch(root + resource, {
    method,
    headers: {
      Authorization: 'Bearer ' + createMockUserToken({sub: uid}, project),
      'Content-Type': 'application/json',
    },
    body: body == null ? undefined : JSON.stringify(body),
  });
  const document = {fields: {
    kind: {stringValue: 'memory'}, authorUid: {stringValue: 'a'}, title: {stringValue: 'Original'},
    caption: {stringValue: ''}, eventAt: {timestampValue: '2026-11-07T00:00:00Z'},
    progress: {integerValue: '0'},
  }};
  const create = await call('a', path + '?currentDocument.exists=false', 'PATCH', document);
  assert(create.ok, await create.clone().text());
  const created = await create.json();
  const version = encodeURIComponent(created.updateTime);
  const queryBody = {structuredQuery: {
    from: [{collectionId: 'entries'}],
    orderBy: [
      {field: {fieldPath: 'eventAt'}, direction: 'DESCENDING'},
      {field: {fieldPath: '__name__'}, direction: 'DESCENDING'},
    ],
    limit: 12,
  }};
  const parent = `nativeStaging/v1/relationshipSpace/${code}:runQuery`;
  const list = await call('b', parent, 'POST', queryBody);
  assert(list.ok, await list.clone().text());
  assert.equal((await list.json())[0].document.fields.title.stringValue, 'Original');
  const projection = await call('b', parent, 'POST', {structuredQuery: {
    ...queryBody.structuredQuery, select: {fields: [{fieldPath: 'eventAt'}]},
  }});
  assert(projection.ok, await projection.clone().text());
  const [row] = await projection.json();
  assert.equal(row.document.updateTime, created.updateTime);
  assert.deepEqual(Object.keys(row.document.fields), ['eventAt']);

  document.fields.title.stringValue = 'New title';
  const competing = structuredClone(document);
  competing.fields.title.stringValue = 'Concurrent edit';
  const writes = await Promise.all([document, competing].map(body =>
    call('a', path + '?currentDocument.updateTime=' + version, 'PATCH', body)));
  assert.equal(writes.filter(response => response.ok).length, 1);
  const winningTitle = writes[0].ok ? 'New title' : 'Concurrent edit';
  const staleDelete = await call('a', path + '?currentDocument.updateTime=' + version, 'DELETE');
  assert(!staleDelete.ok);
  document.fields.title.stringValue = 'Stale overwrite';
  const stale = await call('a', path + '?currentDocument.updateTime=' + version, 'PATCH', document);
  assert.equal((await stale.json()).error.status, 'FAILED_PRECONDITION');
  const duplicate = await call('a', path + '?currentDocument.exists=false', 'PATCH', document);
  assert(!duplicate.ok);
  assert.equal((await getDoc(entry('b'))).data().title, winningTitle);
});
