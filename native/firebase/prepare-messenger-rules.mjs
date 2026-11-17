// Offline only. Assemble the candidate against the exact Build 21 rules.
import { createHash } from 'node:crypto';
import { readFile, writeFile } from 'node:fs/promises';

const [, , source, destination] = process.argv;
if (!source || !destination || process.argv.length !== 4) {
  throw Error('Usage: node prepare-messenger-rules.mjs BUILD21.rules CANDIDATE.rules');
}
const base = await readFile(source, 'utf8');
const expected = '85a5ac576ace519e3ca76f8f1610992cd0d88d1192e300162ac314fe1b4bad7e';
if (createHash('sha256').update(base).digest('hex') !== expected) {
  throw Error('Build 21 Firestore baseline differs. Review before assembling the candidate.');
}
const end = /}\s*}\s*$/.exec(base);
if (!end) throw Error('Missing Build 21 rules boundary.');
const addition = await readFile(new URL('./messenger.proposed.rules', import.meta.url), 'utf8');
const combined = base.slice(0, end.index) + '\n' + addition + '\n' + base.slice(end.index);
await writeFile(destination, combined, { flag: 'wx' });
