import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { after, before, beforeEach, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { Bytes, collection, deleteDoc, doc, getDocFromServer, getDocsFromServer, serverTimestamp, setDoc, updateDoc } from 'firebase/firestore';

const A = 'ABCDEFGHJKLM', B = 'NPQRSTUVWXYZ';
const root = 'nativeStaging/v1';
let env;
const db = uid => uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore();
const ref = (d, uid, code = A) => doc(d, 'reachProfilePhotos', code, 'members', uid);
const photo = (uid, value = 7, length = 8) => ({
  ownerUid: uid, bytes: Bytes.fromUint8Array(new Uint8Array(length).fill(value)), updatedAt: serverTimestamp(),
});

before(async () => {
  const rules = await readFile(process.env.REACH_MESSENGER_RULES_CANDIDATE ?? 'profile-photos.generated.rules', 'utf8');
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
    }
  });
});
after(async () => env?.cleanup());

test('both owners save their portraits and fresh partner sessions see replacements and removals', async () => {
  await assertSucceeds(setDoc(ref(db('a'), 'a'), photo('a')));
  await assertSucceeds(setDoc(ref(db('b'), 'b'), photo('b', 9)));
  assert.equal((await getDocFromServer(ref(db('a'), 'b'))).data().bytes.toUint8Array()[0], 9);
  assert.equal((await getDocFromServer(ref(db('b'), 'a'))).data().bytes.toUint8Array()[0], 7);
  await assertSucceeds(setDoc(ref(db('a'), 'a'), photo('a', 8)));
  assert.equal((await getDocFromServer(ref(db('b'), 'a'))).data().bytes.toUint8Array()[0], 8);
  await assertSucceeds(deleteDoc(ref(db('a'), 'a')));
  assert.equal((await getDocFromServer(ref(db('b'), 'a'))).exists(), false);
  assert.equal((await getDocFromServer(ref(db('a'), 'b'))).exists(), true);
});

test('partner writes, unsafe fields, listing and unrelated access are denied', async () => {
  await assertSucceeds(setDoc(ref(db('a'), 'a'), photo('a', 7, 262144)));
  await assertFails(setDoc(ref(db('b'), 'a'), photo('a')));
  await assertFails(deleteDoc(ref(db('b'), 'a')));
  await assertFails(setDoc(ref(db('a'), 'a'), photo('b')));
  await assertFails(setDoc(ref(db('a'), 'a'), photo('a', 7, 262145)));
  await assertFails(setDoc(ref(db('a'), 'a'), photo('a', 7, 0)));
  await assertFails(setDoc(ref(db('a'), 'a'), { ...photo('a'), publicURL: 'blocked' }));
  await assertFails(getDocFromServer(doc(db('a'), root, 'memberLocks', 'b')));
  await assertFails(getDocFromServer(ref(db('a'), 'c')));
  await assertFails(getDocsFromServer(collection(db('a'), 'reachProfilePhotos', A, 'members')));
  for (const uid of [undefined, 'guest', 'c', 'd']) {
    await assertFails(getDocFromServer(ref(db(uid), 'a')));
    await assertFails(setDoc(ref(db(uid), 'a'), photo('a')));
    await assertFails(deleteDoc(ref(db(uid), 'a')));
  }
});

test('a mismatched lock or revocation denies both partners subsequent access', async () => {
  await setDoc(ref(db('a'), 'a'), photo('a'));
  await env.withSecurityRulesDisabled(async context => {
    await updateDoc(doc(context.firestore(), root, 'memberLocks', 'b'), { pairCode: B });
  });
  await assertFails(getDocFromServer(ref(db('a'), 'a')));
  await assertFails(getDocFromServer(ref(db('b'), 'a')));
  await assertFails(setDoc(ref(db('a'), 'a'), photo('a')));
  await env.withSecurityRulesDisabled(async context => {
    await updateDoc(doc(context.firestore(), root, 'memberLocks', 'b'), { pairCode: A });
    await updateDoc(doc(context.firestore(), root, 'pairInvites', A), { revoked: true });
  });
  await assertFails(getDocFromServer(ref(db('b'), 'a')));
  await assertFails(setDoc(ref(db('b'), 'b'), photo('b')));
  await assertFails(deleteDoc(ref(db('a'), 'a')));
});
