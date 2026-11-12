import assert from 'node:assert/strict';
import { test } from 'node:test';
import { planAdventureBookQuotas, verifyAdventureBookQuotaInventory } from './adventure-book-quota-plan.mjs';

const A = 'ABCDEFGHJKLM', B = 'NPQRSTUVWXYZ', C = '23456789ABCD', D = '23456789EFGH';

test('offline quota plan distinguishes clean backfill, existing counts, drift and overflow', () => {
  const plan = planAdventureBookQuotas({ creationFrozen: true, books: [
    { pairCode: B, memoryCount: 501 },
    { pairCode: A, memoryCount: 0 },
    { pairCode: C, memoryCount: 500, existingQuota: 500 },
    { pairCode: D, memoryCount: 12, existingQuota: 11 },
  ] });
  const byCode = Object.fromEntries(plan.books.map(book => [book.pairCode, book]));
  assert.equal(plan.reviewOnly, true);
  assert.deepEqual(byCode[A].proposedQuota, { count: 0, lastMemoryID: null });
  assert.equal(byCode[B].state, 'over-limit');
  assert.equal(byCode[B].proposedQuota, null);
  assert.equal(byCode[C].state, 'verified');
  assert.equal(byCode[D].state, 'reconcile');
  assert.equal(byCode[D].proposedQuota, null);
});

test('offline quota planner rejects a missing freeze, duplicates and invalid inventory', () => {
  const valid = { pairCode: A, memoryCount: 1 };
  assert.throws(() => planAdventureBookQuotas({ books: [valid] }), /frozen/);
  for (const books of [[valid, valid], [{ ...valid, memoryCount: -1 }], [{ ...valid, existingQuota: 1.5 }]]) {
    assert.throws(() => planAdventureBookQuotas({ creationFrozen: true, books }), /Invalid or duplicate/);
  }
});

test('verification detects dropped books, quota drift and writes during the freeze', () => {
  const inventory = books => ({ creationFrozen: true, books });
  const original = inventory([{ pairCode: A, memoryCount: 2 }, { pairCode: B, memoryCount: 0 }]);
  const verified = inventory([{ pairCode: A, memoryCount: 2, existingQuota: 2 },
    { pairCode: B, memoryCount: 0, existingQuota: 0 }]);
  assert.equal(verifyAdventureBookQuotaInventory(original, verified).ready, true);
  const changed = inventory([{ pairCode: A, memoryCount: 3, existingQuota: 2 },
    { pairCode: C, memoryCount: 0, existingQuota: 0 }]);
  assert.deepEqual(verifyAdventureBookQuotaInventory(original, changed).issues.map(issue => issue.reason).sort(),
    ['inventory-changed', 'missing-book', 'reconcile', 'unexpected-book']);
});
