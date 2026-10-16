// REACH dependency-free static checks. These are NOT Firebase emulator tests.
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const html = fs.readFileSync('../index.html','utf8');
const rules = fs.readFileSync('../firestore.security-candidate.rules','utf8');
const scripts = [...html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi)];
assert.ok(scripts.length >= 2, 'Expected inline app scripts');
for (const [index, script] of scripts.entries()) {
  const source = script[2];
  // Strip static CDN imports solely for syntax-checking with vm.Script.
  const body = source.replace(/^\s*import\s*(?:\{[\s\S]*?\}|[A-Za-z_$][\w$]*)\s*from\s*["'][^"']+["'];/gm, '');
  new vm.Script(body, {filename: 'inline-script-' + index + '.js'});
}
const checks = [
  ['default deny', /match \/\{document=\*\*\}\s*\{\s*allow read, write: if false/.test(rules)],
  ['role-specific candidates', rules.includes('match /hostCandidates/{candidateId}') && rules.includes('match /partnerCandidates/{candidateId}')],
  ['no wildcard signaling writes', !rules.includes('match /{signalDocument=**}')],
  ['member lock enforcement', rules.includes('match /memberLocks/{uid}') && rules.includes('newPairLock(request.auth.uid, pairCode)')],
  ['revocation enforcement', rules.includes("get('revoked', false)")],
  ['expiry enforcement', rules.includes('expiresAt > request.time.toMillis()')],
  ['room ownership check', rules.includes('data.pairCode == pairCode')],
  ['secure room code generator', html.includes('crypto.getRandomValues(new Uint8Array(6))')],
  ['host-only room pointer cleanup', html.includes('pairSessionCode && endingRole==="host"')],
  ['read-only connection check exists', html.includes('window.checkPairHealth = async function()')],
  ['connection check compares local pairing and permanent lock', html.includes('phone pairing and security lock disagree')],
  ['connection check identifies authenticated phone', html.includes('This phone UID: ')],

];
for (const [name, pass] of checks) {
  assert.ok(pass, 'Failed static invariant: ' + name);
  console.log('PASS ' + name);
}
console.log('PASS inline script syntax (' + scripts.length + ' scripts)');
console.log('Static checks passed. Firebase permissions remain UNTESTED.');
