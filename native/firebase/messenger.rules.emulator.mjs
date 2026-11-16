import { after, before, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import {
  collection, deleteDoc, disableNetwork, doc, documentId, enableNetwork, getDocFromServer,
  getDocsFromServer, limit, onSnapshot, orderBy, query, serverTimestamp, setDoc, startAfter, updateDoc
} from 'firebase/firestore';

const code = 'ABCDEFGHJKLM';
const otherCode = 'NPQRSTUVWXYZ';
const ids = [1, 2, 3].map(n => '00000000-0000-4000-8000-00000000000' + n);
let env;

const db = uid => (uid ? env.authenticatedContext(uid) : env.unauthenticatedContext()).firestore();
const messages = d => collection(d, 'messenger', code, 'messages');
const message = (d, id = ids[0]) => doc(messages(d), id);
const receipt = (d, uid) => doc(d, 'messenger', code, 'readReceipts', uid);
const pair = (d, id = code) => doc(d, 'nativeStaging', 'v1', 'pairInvites', id);
const lock = (d, uid) => doc(d, 'nativeStaging', 'v1', 'memberLocks', uid);
const data = (uid, text = 'Hello') => ({ senderUid: uid, kind: 'text', text, createdAt: serverTimestamp() });
const admin = operation => env.withSecurityRulesDisabled(ctx => operation(ctx.firestore()));

before(async () => {
  const base = await readFile('profile-photos.generated.rules', 'utf8');
  const addition = await readFile('messenger.proposed.rules', 'utf8');
  const end = /}\s*}\s*$/.exec(base);
  assert.ok(end);
  env = await initializeTestEnvironment({
    projectId: 'demo-reach-messenger',
    firestore: { rules: base.slice(0, end.index) + '\n' + addition + '\n' + base.slice(end.index) }
  });
});

beforeEach(async () => {
  await env.clearFirestore();
  await admin(async d => {
    for (const [id, hostUid, partnerUid] of [[code, 'a', 'b'], [otherCode, 'c', 'd']]) {
      await setDoc(pair(d, id), { hostUid, partnerUid, revoked: false });
      await setDoc(lock(d, hostUid), { pairCode: id });
      await setDoc(lock(d, partnerUid), { pairCode: id });
    }
  });
});

after(async () => { await env?.cleanup(); });

test('partners can exchange messages while strangers and guests cannot read or write', async () => {
  await assertSucceeds(setDoc(message(db('a')), data('a')));
  await assertSucceeds(setDoc(message(db('b'), ids[1]), data('b', 'Hi')));
  assert.equal((await getDocFromServer(message(db('b')))).data().text, 'Hello');
  for (const uid of [undefined, 'c']) {
    const d = db(uid);
    await assertFails(getDocFromServer(message(d)));
    await assertFails(getDocsFromServer(query(messages(d), limit(20))));
    await assertFails(setDoc(message(d, ids[2]), data(uid ?? 'a')));
  }
});

test('sender identity, immutable IDs, payload size and server timestamps are enforced', async () => {
  const a = db('a');
  for (const invalid of [
    data('b'), data('a', ''), data('a', '🙂'.repeat(1001)),
    { ...data('a'), createdAt: new Date(0) },
    { ...data('a'), attachment: 'unsupported' }
  ]) {
    await assertFails(setDoc(message(a), invalid));
  }
  await assertFails(setDoc(message(a, 'invalid'), data('a')));
  await assertSucceeds(setDoc(message(a), data('a', '🙂'.repeat(1000))));
  await assertFails(setDoc(message(a), data('a', 'Duplicate')));
  await assertFails(updateDoc(message(a), { text: 'Changed' }));
  await assertFails(deleteDoc(message(db('b'))));
});

test('cursor pages are bounded and stable when timestamps tie', async () => {
  const a = db('a');
  await admin(async d => {
    for (const id of ids) await setDoc(message(d, id), { ...data('a'), createdAt: new Date(0) });
  });
  await assertFails(getDocsFromServer(messages(a)));
  await assertFails(getDocsFromServer(query(messages(a), limit(51))));
  const sorted = query(messages(a), orderBy('createdAt', 'desc'), orderBy(documentId(), 'desc'));
  const first = await getDocsFromServer(query(sorted, limit(2)));
  const next = await getDocsFromServer(query(sorted, startAfter(first.docs.at(-1)), limit(2)));
  assert.deepEqual([...first.docs, ...next.docs].map(doc => doc.id), [...ids].reverse());
});

test('read receipt is private, references a real message and cannot regress in time', async () => {
  const a = db('a');
  const b = db('b');
  await admin(async d => {
    await setDoc(message(d), { ...data('b'), createdAt: new Date(1000) });
    await setDoc(message(d, ids[1]), { ...data('b'), createdAt: new Date(2000) });
  });
  const newest = { messageID: ids[1], createdAt: new Date(2000) };
  await assertFails(setDoc(receipt(a, 'b'), newest));
  await assertFails(setDoc(receipt(a, 'a'), { ...newest, messageID: ids[2] }));
  await assertSucceeds(setDoc(receipt(a, 'a'), newest));
  await assertFails(getDocFromServer(receipt(b, 'a')));
  await assertFails(setDoc(receipt(a, 'a'), { messageID: ids[0], createdAt: new Date(1000) }));
});

test('a queued write is denied when reconnecting after revocation', { timeout: 15000 }, async () => {
  const a = db('a');
  await assertSucceeds(setDoc(message(a), data('a')));
  await disableNetwork(a);
  const queued = assertFails(setDoc(message(a, ids[1]), data('a')));

  await admin(d => updateDoc(pair(d), { revoked: true }));
  await enableNetwork(a);
  await queued;
  await assertFails(getDocFromServer(message(a)));
  await admin(async d => {
    assert.equal((await getDocFromServer(message(d))).data().text, 'Hello');
    assert.equal((await getDocFromServer(message(d, ids[1]))).exists(), false);
  });
});

test('the server denies access when either member lock changes', async () => {
  await admin(d => setDoc(lock(d, 'b'), { pairCode: otherCode }));
  await assertFails(setDoc(message(db('a')), data('a')));
  await assertFails(setDoc(message(db('b')), data('b')));
});

test('an authorized queued write syncs once after coming back online', { timeout: 15000 }, async () => {
  const a = db('a');
  await disableNetwork(a);
  const queued = assertSucceeds(setDoc(message(a), data('a')));
  await enableNetwork(a);
  await queued;
  const page = await getDocsFromServer(query(messages(db('b')), limit(50)));
  assert.deepEqual(page.docs.map(doc => doc.id), [ids[0]]);
});

test('a partner receives a committed message on a live listener', { timeout: 15000 }, async () => {
  const b = db('b');
  const received = Promise.withResolvers();
  const stop = onSnapshot(query(messages(b), limit(50)), page => {
    if (page.docs.some(doc => doc.id === ids[0])) received.resolve();
  }, received.reject);
  try {
    await assertSucceeds(setDoc(message(db('a')), data('a')));
    await received.promise;
  } finally {
    stop();
  }
});
