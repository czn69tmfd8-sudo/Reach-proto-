import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { after, before, beforeEach, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { collection, doc, getDoc, getDocFromServer, getDocs, limit, onSnapshot, query, runTransaction, serverTimestamp, setDoc, updateDoc, writeBatch } from 'firebase/firestore';

let env;
let candidateRules;
const projectId = 'demo-reach-adventure';
const A = 'ABCDEFGHJKLM';
const B = 'NPQRSTUVWXYZ';
const root = 'nativeStaging/v1';
const db = uid => env.authenticatedContext(uid).firestore();
const quota = (d, code = A) => doc(d, 'adventureBookQuotas', code);
const memory = (d, id, code = A) => doc(d, 'adventureBooks', code, 'memories', id);
const fields = (uid, code = A) => ({
  pairCode: code, creatorUid: uid, title: 'Our memory', occurredAt: new Date(0),
  pageOrder: 0, createdAt: serverTimestamp(),
});

before(async () => {
  candidateRules = await readFile('adventure-book.shared-quota.generated.rules', 'utf8');
  env = await initializeTestEnvironment({ projectId, firestore: { rules: candidateRules } });
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async context => {
    const d = context.firestore();
    const batch = writeBatch(d);
    for (const [code, host, partner] of [[A, 'a', 'b'], [B, 'c', 'd']]) {
      batch.set(doc(d, root, 'pairInvites', code), { hostUid: host, partnerUid: partner, revoked: false });
      batch.set(doc(d, root, 'memberLocks', host), { pairCode: code });
      batch.set(doc(d, root, 'memberLocks', partner), { pairCode: code });
      batch.set(memory(d, 'legacy', code), fields(host, code));
    }
    batch.set(quota(d), { count: 1, lastMemoryID: null });
    await batch.commit();
  });
});

after(async () => env?.cleanup());

function create(d, id, uid, code = A) {
  return runTransaction(d, async tx => {
    const current = await tx.get(quota(d, code));
    const previous = await tx.get(memory(d, id, code));
    if (previous.exists()) {
      if (previous.data().creatorUid !== uid || previous.data().title !== 'Our memory') {
        throw Error('memory-conflict');
      }
      return;
    }
    if (!current.exists() || current.data().count >= 500) throw Error('memory-limit');
    tx.set(memory(d, id, code), fields(uid, code));
    tx.update(quota(d, code), { count: current.data().count + 1, lastMemoryID: id });
  });
}

function attemptBatch(d, ids, count, marker, uid = 'a') {
  const batch = writeBatch(d);
  for (const id of ids) batch.set(memory(d, id), fields(uid));
  batch.update(quota(d), { count, lastMemoryID: marker });
  return batch.commit();
}

test('concurrent partners at 499 can add only one memory, and its retry consumes no slot', async () => {
  await env.withSecurityRulesDisabled(async context => {
    const d = context.firestore();
    const batch = writeBatch(d);
    for (let index = 0; index < 498; index++) batch.set(memory(d, 'seed-' + index), fields('a'));
    batch.update(quota(d), { count: 499 });
    await batch.commit();
  });
  const contenders = [['a', 'last-a'], ['b', 'last-b']];
  const results = await Promise.allSettled(contenders.map(([uid, id]) => create(db(uid), id, uid)));
  assert.equal(results.filter(result => result.status === 'fulfilled').length, 1);
  const winner = results.findIndex(result => result.status === 'fulfilled');
  const [uid, id] = contenders[winner];
  const rejection = results[1 - winner].reason;
  assert.ok(rejection.message === 'memory-limit' || rejection.code === 'permission-denied',
    'the loser must reach the cap check or be rejected by server rules');
  const [loserUID, loserID] = contenders[1 - winner];
  const loserDB = db(loserUID);
  assert.equal((await getDoc(quota(loserDB))).data().count, 500);
  assert.equal((await getDoc(memory(loserDB, loserID))).exists(), false);
  await assertSucceeds(create(db(uid), id, uid));
  // A client that ignores the transaction's local limit is still denied.
  await assertFails(attemptBatch(db('a'), ['bypass'], 501, 'bypass'));
  await env.withSecurityRulesDisabled(async context => {
    const all = await getDocs(collection(context.firestore(), 'adventureBooks', A, 'memories'));
    assert.equal(all.size, 500);
  });
});

test('counter and memory writes cannot be separated, spoofed, or reused by a second create', async () => {
  const a = db('a');
  await assertFails(setDoc(memory(a, 'standalone'), fields('a')));
  await assertFails(updateDoc(quota(a), { count: 2, lastMemoryID: 'absent' }));
  await assertFails(updateDoc(quota(a), { count: 2, lastMemoryID: 'legacy' }));
  await assertFails(attemptBatch(a, ['one', 'two'], 2, 'one'));
  await assertFails(attemptBatch(a, ['one'], 3, 'one'));
  await assertFails(attemptBatch(a, ['one'], 0, 'one'));
  await assertFails(attemptBatch(a, ['one'], 2, 'one', 'b'));
  assert.equal((await getDoc(quota(a))).data().count, 1);
  assert.equal((await getDoc(memory(a, 'one'))).exists(), false);
  await assertSucceeds(create(a, 'one', 'a'));
  assert.equal((await getDoc(quota(a))).data().count, 2);
});

test('missing backfill fails closed while legacy reads, updates, and stories still work', async () => {
  const c = db('c');
  await assertFails(setDoc(quota(c, B), { count: 0, lastMemoryID: null }));
  await assertFails(setDoc(memory(c, 'new', B), fields('c', B)));
  await assert.rejects(create(c, 'new', 'c', B), /memory-limit/);
  await assertSucceeds(getDoc(memory(c, 'legacy', B)));
  await assertSucceeds(updateDoc(memory(c, 'legacy', B), { title: 'Preserved legacy' }));
  await assertSucceeds(setDoc(doc(memory(c, 'legacy', B), 'stories', 'c'), {
    authorUid: 'c', text: 'Preserved story', updatedAt: serverTimestamp(),
  }));
});

test('cross-couple clients, revoked pairs, and missing locks cannot consume quota', async () => {
  const a = db('a');
  const outsider = db('c');
  await assertFails(getDoc(quota(outsider)));
  await assertFails(attemptBatch(outsider, ['other-couple'], 2, 'other-couple', 'c'));
  await env.withSecurityRulesDisabled(async context => {
    const d = context.firestore();
    await updateDoc(doc(d, root, 'memberLocks', 'b'), { pairCode: B });
  });
  await assertFails(attemptBatch(a, ['lock-changed'], 2, 'lock-changed'));
  await env.withSecurityRulesDisabled(async context => {
    const d = context.firestore();
    await updateDoc(doc(d, root, 'memberLocks', 'b'), { pairCode: A });
    await updateDoc(doc(d, root, 'pairInvites', A), { revoked: true });
  });
  await assertFails(attemptBatch(a, ['revoked'], 2, 'revoked'));
});

test('cutover and rollback freeze creation while preserving inventory, quota and legacy edits', async () => {
  const frozenRules = await readFile('adventure-book.shared-quota.generated.frozen.rules', 'utf8');
  const ruleContexts = [];
  async function install(rules) {
    ruleContexts.push(await initializeTestEnvironment({ projectId, firestore: { rules } }));
  }

  const a = db('a'), c = db('c');
  try {
    await install(frozenRules);
    await assertFails(setDoc(memory(c, 'old-client', B), fields('c', B)));
    await assertFails(attemptBatch(a, ['frozen'], 2, 'frozen'));
    await assertSucceeds(updateDoc(memory(c, 'legacy', B), { title: 'Edited during freeze' }));

    // The privileged inventory counts actual documents before provisioning B.
    await env.withSecurityRulesDisabled(async context => {
      const d = context.firestore();
      const inventory = await getDocs(collection(d, 'adventureBooks', B, 'memories'));
      assert.equal(inventory.size, 1);
      await setDoc(quota(d, B), { count: inventory.size, lastMemoryID: null });
    });
    await install(candidateRules);
    await assertSucceeds(create(c, 'after-cutover', 'c', B));
    assert.equal((await getDoc(quota(c, B))).data().count, 2);

    // Roll back to the freeze, never to a ruleset allowing uncounted creates.
    await install(frozenRules);
    await assertFails(setDoc(memory(c, 'uncounted', B), fields('c', B)));
    await assertFails(create(c, 'blocked-during-rollback', 'c', B));
    assert.equal((await getDoc(quota(c, B))).data().count, 2);
    assert.equal((await getDoc(memory(c, 'legacy', B))).data().title, 'Edited during freeze');
    assert.equal((await getDoc(memory(c, 'after-cutover', B))).exists(), true);

    await install(candidateRules);
    await assertSucceeds(create(c, 'after-cutover', 'c', B));
    await assertSucceeds(create(c, 'after-resume', 'c', B));
    assert.equal((await getDoc(quota(c, B))).data().count, 3);
  } finally {
    await Promise.all(ruleContexts.map(context => context.cleanup()));
  }
});

test('paired clients sync memories, both stories and conversation without partner lock access', async () => {
  const host = db('a'), partner = db('b');
  const lock = (d, uid) => doc(d, root, 'memberLocks', uid);
  await assertSucceeds(getDoc(lock(host, 'a')));
  await assertFails(getDoc(lock(host, 'b')));
  await assertFails(getDoc(lock(partner, 'a')));
  const books = query(collection(partner, 'adventureBooks', A, 'memories'), limit(50));
  async function watch(ref, predicate, mutate) {
    let stop, timer;
    try {
      let ready;
      const initial = new Promise(resolve => { ready = resolve; });
      const result = new Promise((resolve, reject) => {
        timer = setTimeout(() => reject(Error('Timed out waiting for server snapshot')), 15000);
        stop = onSnapshot(ref, { includeMetadataChanges: true }, snapshot => {
          if (snapshot.metadata.fromCache || snapshot.metadata.hasPendingWrites) return;
          ready();
          if (predicate(snapshot)) resolve();
        }, reject);
      });
      await Promise.all([result, (async () => { await initial; await mutate(); })()]);
    } finally {
      clearTimeout(timer);
      stop?.();
    }
  }
  await watch(books, s => s.docs.some(d => d.id === 'shared'), () => create(host, 'shared', 'a'));
  const child = (d, name, id) => doc(memory(d, 'shared'), name, id);
  const stories = query(collection(memory(host, 'shared'), 'stories'), limit(2));
  await watch(stories, s => s.docs.some(d => d.data().text === 'Partner story'),
    () => setDoc(child(partner, 'stories', 'b'), { authorUid: 'b', text: 'Partner story', updatedAt: serverTimestamp() }));
  await assertSucceeds(setDoc(child(host, 'stories', 'a'), {
    authorUid: 'a', text: 'Host story', updatedAt: serverTimestamp(),
  }));
  await assertSucceeds(updateDoc(child(host, 'stories', 'a'), { text: 'Revised', updatedAt: serverTimestamp() }));
  assert.equal((await getDoc(child(partner, 'stories', 'a'))).data().text, 'Revised');
  await assertFails(updateDoc(child(partner, 'stories', 'a'), { text: 'Overwrite', updatedAt: serverTimestamp() }));
  const comments = query(collection(memory(partner, 'shared'), 'comments'), limit(50));
  await watch(comments, s => s.docs.some(d => d.data().text === 'Our conversation'),
    () => setDoc(child(host, 'comments', 'first'), { authorUid: 'a', text: 'Our conversation', createdAt: serverTimestamp() }));
  await assertFails(setDoc(child(host, 'photos', 'blocked'), {
    ownerUid: 'a', storagePath: 'adventureBook/' + A + '/shared/blocked',
    caption: '', position: 0, createdAt: serverTimestamp(),
  }));
  await env.withSecurityRulesDisabled(context => updateDoc(lock(context.firestore(), 'a'), { pairCode: B }));
  await assertFails(getDoc(quota(partner)));
  await assertFails(getDocs(books));
});

test('a fresh server recheck denies an open session when only the other lock changes', async () => {
  const partner = db('b');
  const access = quota(partner);
  await assertSucceeds(getDocFromServer(access));
  await env.withSecurityRulesDisabled(context =>
    updateDoc(doc(context.firestore(), root, 'memberLocks', 'a'), { pairCode: B }));
  await assertFails(getDocFromServer(access));
});
