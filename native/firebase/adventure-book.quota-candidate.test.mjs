import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { after, before, beforeEach, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { collection, doc, getDoc, getDocs, runTransaction, serverTimestamp, setDoc, updateDoc, writeBatch } from 'firebase/firestore';

// Apply the candidate only in memory to the emulator fixture. The reviewed
// additive rules and deployment/merge paths never consume this candidate.
const createTail = '    && request.resource.data.createdAt == request.time;\n  allow update: if adventureAuthorized(code) && adventureMemoryShape';
const counterRules = `
function adventureQuotaPath(code) {
  return /databases/$(database)/documents/adventureBookQuotas/$(code);
}
function adventureMemoryPath(code, memoryID) {
  return /databases/$(database)/documents/adventureBooks/$(code)/memories/$(memoryID);
}
function adventureQuotaIncrement(before, after, memoryID) {
  return before.count is int && before.count >= 0 && before.count < 500
    && after.keys().hasOnly(['count', 'lastMemoryID'])
    && after.count is int && after.count == before.count + 1
    && after.lastMemoryID == memoryID;
}
function adventureCreateConsumesQuota(code, memoryID) {
  let quota = adventureQuotaPath(code);
  return adventureQuotaIncrement(get(quota).data, getAfter(quota).data, memoryID);
}
function adventureNewQuotaMemory(code, memoryID) {
  let memory = adventureMemoryPath(code, memoryID);
  return !exists(memory) && existsAfter(memory);
}
match /adventureBookQuotas/{code} {
  allow get: if adventureAuthorized(code);
  allow update: if adventureAuthorized(code)
    && request.resource.data.lastMemoryID is string
    && request.resource.data.lastMemoryID.matches('[A-Za-z0-9_-]{1,128}')
    && adventureQuotaIncrement(resource.data, request.resource.data, request.resource.data.lastMemoryID)
    && adventureNewQuotaMemory(code, request.resource.data.lastMemoryID);
}
`;

let env;
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
  const baseline = await readFile('adventure-book.combined.generated.rules', 'utf8');
  assert.equal(baseline.split(createTail).length, 2, 'reviewed create rule changed');
  const marker = 'match /adventureBooks/{code}/memories/{memoryID} {';
  assert.equal(baseline.split(marker).length, 2, 'reviewed memory match changed');
  const rules = baseline
    .replace(createTail, createTail.replace('request.time;', 'request.time\n    && adventureCreateConsumesQuota(code, memoryID);'))
    .replace(marker, counterRules + marker);
  env = await initializeTestEnvironment({ projectId: 'demo-reach-adventure', firestore: { rules } });
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
