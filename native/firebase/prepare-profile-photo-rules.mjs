// Offline only. Generate a candidate from the exact Build 20 Firestore baseline.
import { createHash } from 'node:crypto';
import { readFile, writeFile } from 'node:fs/promises';

const [, , source, destination] = process.argv;
if (!source || !destination || process.argv.length !== 4) {
  throw Error('Usage: node prepare-profile-photo-rules.mjs BUILD20.rules CANDIDATE.rules');
}
const base = await readFile(source, 'utf8');
const expected = 'becca883407bb612f51ce6968eb2c57550732b433ad04386932786a78c2e295b';
if (createHash('sha256').update(base).digest('hex') !== expected) {
  throw Error('Build 20 Firestore baseline differs. Review before assembling the candidate.');
}
const end = /}\s*}\s*$/.exec(base);
const addition = await readFile(new URL('./profile-photos.rules', import.meta.url), 'utf8');
await writeFile(destination, base.slice(0, end.index) + '\n' + addition + '\n' + base.slice(end.index), { flag: 'wx' });
