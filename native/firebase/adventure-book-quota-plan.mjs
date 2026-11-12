import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';

const validPair = /^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{12}$/;
const cap = 500;

// Builds a review-only plan from a trusted inventory captured while all
// memory creation is frozen. It has no Firebase or credentials dependency.
export function planAdventureBookQuotas(input) {
  if (input?.creationFrozen !== true || !Array.isArray(input.books)) {
    throw Error('A frozen creation window and a book inventory are required');
  }
  const seen = new Set();
  const books = input.books.map(entry => {
    const { pairCode, memoryCount, existingQuota = null } = entry ?? {};
    if (typeof pairCode !== 'string' || !validPair.test(pairCode) || seen.has(pairCode)
        || !Number.isSafeInteger(memoryCount) || memoryCount < 0
        || (existingQuota !== null && (!Number.isSafeInteger(existingQuota) || existingQuota < 0))) {
      throw Error('Invalid or duplicate book inventory entry');
    }
    seen.add(pairCode);
    const state = memoryCount > cap ? 'over-limit'
      : existingQuota === null ? 'backfill'
      : existingQuota === memoryCount ? 'verified' : 'reconcile';
    return { pairCode, memoryCount, existingQuota, state,
      proposedQuota: state === 'backfill' ? { count: memoryCount, lastMemoryID: null } : null };
  }).sort((a, b) => a.pairCode.localeCompare(b.pairCode));
  return { reviewOnly: true, books };
}

export function verifyAdventureBookQuotaInventory(expected, actual) {
  const original = new Map(planAdventureBookQuotas(expected).books.map(book => [book.pairCode, book]));
  const issues = [];
  for (const book of planAdventureBookQuotas(actual).books) {
    const before = original.get(book.pairCode);
    original.delete(book.pairCode);
    if (!before) issues.push({ pairCode: book.pairCode, reason: 'unexpected-book' });
    else if (before.memoryCount !== book.memoryCount) {
      issues.push({ pairCode: book.pairCode, reason: 'inventory-changed' });
    }
    if (book.state !== 'verified') issues.push({ pairCode: book.pairCode, reason: book.state });
  }
  for (const pairCode of original.keys()) issues.push({ pairCode, reason: 'missing-book' });
  return { reviewOnly: true, ready: issues.length === 0, issues };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const [, , inventory, verifiedInventory] = process.argv;
  if (!inventory || process.argv.length > 4) {
    throw Error('Usage: node adventure-book-quota-plan.mjs INVENTORY.json [VERIFIED-INVENTORY.json]');
  }
  const input = JSON.parse(await readFile(inventory, 'utf8'));
  const result = verifiedInventory
    ? verifyAdventureBookQuotaInventory(input, JSON.parse(await readFile(verifiedInventory, 'utf8')))
    : planAdventureBookQuotas(input);
  process.stdout.write(JSON.stringify(result, null, 2) + '\n');
  if (verifiedInventory && !result.ready) process.exitCode = 1;
}
