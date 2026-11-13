// Offline only. Pass a reviewed, read-only export of the active Firestore rules.
import { createHash } from 'node:crypto';
import { readFile, writeFile } from 'node:fs/promises';

const [, , basePath, prefix] = process.argv;
if (!basePath || !prefix || process.argv.length !== 4) {
  throw Error('Usage: node prepare-shared-adventure-rules.mjs BASE.rules OUTPUT_PREFIX');
}
const base = await readFile(basePath, 'utf8');
const addition = await readFile(new URL('./adventure-book.shared-quota.rules', import.meta.url), 'utf8');
const end = /}\s*}\s*$/.exec(base);
if (!end || !base.includes('service cloud.firestore') ||
    !base.includes('match /nativeStaging/v1') ||
    !base.includes('match /memberLocks/{uid}') ||
    !base.includes('match /pairInvites/{code}') ||
    /adventureBooks|adventureBookQuotas|function\s+adventure/u.test(base)) {
  throw Error('Unexpected Firestore baseline or existing Adventure Book rules. Review manually.');
}
const create = '&& adventureCreateConsumesQuota(code, memoryID);';
const increment = '&& adventureNewQuotaMemory(code, request.resource.data.lastMemoryID);';
if ([create, increment].some(marker => addition.split(marker).length !== 2)) {
  throw Error('Quota rule markers changed. Review the freeze before proceeding.');
}
const frozen = addition.replace(create, '&& false;').replace(increment, '&& false;');
const merge = rules => base.slice(0, end.index) + '\n' + rules + '\n' + base.slice(end.index);
const enforced = merge(addition);
const frozenRules = merge(frozen);
const sha = source => createHash('sha256').update(source).digest('hex');
await writeFile(prefix + '.rules', enforced, { flag: 'wx' });
await writeFile(prefix + '.frozen.rules', frozenRules, { flag: 'wx' });
await writeFile(prefix + '.manifest.json', JSON.stringify({
  project: 'reach-staging-a4745', reviewOnly: true,
  baseSHA256: sha(base), enforcedSHA256: sha(enforced), frozenSHA256: sha(frozenRules),
}, null, 2) + '\n', { flag: 'wx' });
