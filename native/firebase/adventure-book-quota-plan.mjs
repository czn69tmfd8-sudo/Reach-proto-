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

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  if (process.argv.length !== 3) throw Error('Usage: node adventure-book-quota-plan.mjs INVENTORY.json');
  const input = JSON.parse(await readFile(process.argv[2], 'utf8'));
  process.stdout.write(JSON.stringify(planAdventureBookQuotas(input), null, 2) + '\n');
}
