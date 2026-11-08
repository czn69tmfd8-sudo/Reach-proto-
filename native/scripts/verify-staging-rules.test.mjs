import assert from 'node:assert/strict';
import {generateKeyPairSync, verify as verifySignature} from 'node:crypto';
import {mkdtemp, readFile, readdir, rm, stat} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {test} from 'node:test';
import {baselineSHA, candidateSHA, verify} from './verify-staging-rules.mjs';

const project = 'reach-staging-a4745';
const releaseName = `projects/${project}/releases/cloud.firestore`;
const rulesetName = `projects/${project}/rulesets/fixture-1`;
const release = {name: releaseName, rulesetName, updateTime: '2026-11-07T22:30:59.996Z'};
const review = new URL('../firebase/reviews/', import.meta.url);
const baseline = await readFile(new URL('staging-2026-11-06-hardened/merged.rules', review));
const candidate = await readFile(new URL('staging-relationship-space/merged.rules', review));
const {privateKey, publicKey} = generateKeyPairSync('rsa', {modulusLength: 2048});
const credential = {
  type: 'service_account', project_id: project,
  client_email: `reach-staging-rules-reader@${project}.iam.gserviceaccount.com`,
  private_key: privateKey.export({type: 'pkcs8', format: 'pem'}),
};
const env = {
  CM_BRANCH: 'native-reach', REACH_RULES_PRIVATE_ARTIFACTS_CONFIRMED: 'yes',
  REACH_STAGING_RULES_READER_JSON: JSON.stringify(credential),
};

async function fixture(t, {first = release, last = first, source = baseline.toString(),
                           ruleset = {name: rulesetName, source: {files: [{content: source}]}}} = {}) {
  const root = await mkdtemp(join(tmpdir(), 'reach-rules-test-'));
  t.after(() => rm(root, {recursive: true, force: true}));
  const output = join(root, 'artifact');
  const calls = [];
  const fetcher = async (url, options) => {
    calls.push([url, options]);
    const replies = [{access_token: 'fixture-token'}, first, ruleset, last];
    return Response.json(replies[calls.length - 1]);
  };
  return {root, output, calls, options: {env, output, candidate, fetcher}};
}

test('reads only the pinned release and ruleset and saves exact private rollback bytes', async t => {
  const {output, calls, options} = await fixture(t);
  const result = await verify(options);
  assert.equal(result.result, 'verified');
  assert.equal(result.activeSHA256, baselineSHA);
  assert.equal(result.candidateSHA256, candidateSHA);
  assert.deepEqual(JSON.parse(await readFile(join(output, 'verification.json'))), result);
  assert.deepEqual(await readFile(join(output, 'active.rules')), baseline);
  assert.equal((await stat(join(output, 'active.rules'))).mode & 0o777, 0o600);
  assert.deepEqual(calls.map(([url, options]) => [options.method, url]), [
    ['POST', 'https://oauth2.googleapis.com/token'],
    ['GET', `https://firebaserules.googleapis.com/v1/${releaseName}`],
    ['GET', `https://firebaserules.googleapis.com/v1/${rulesetName}`],
    ['GET', `https://firebaserules.googleapis.com/v1/${releaseName}`],
  ]);
  assert.ok(calls.every(([, options]) => options.redirect === 'error'));
  const [header, claims, signature] = calls[0][1].body.get('assertion').split('.');
  const jwt = JSON.parse(Buffer.from(claims, 'base64url'));
  assert.equal(jwt.scope, 'https://www.googleapis.com/auth/firebase.readonly');
  assert.equal(jwt.exp - jwt.iat, 300);
  assert.ok(verifySignature('RSA-SHA256', Buffer.from(`${header}.${claims}`),
    publicKey, Buffer.from(signature, 'base64url')));
});

test('changed live source yields a release hold and retains the exact snapshot', async t => {
  const source = 'rules_version = \'2\';\r\n// fixture — trailing space \r\n';
  const {output, options} = await fixture(t, {source});
  assert.equal((await verify(options)).result, 'release-hold');
  assert.equal(await readFile(join(output, 'active.rules'), 'utf8'), source);
});

test('candidate mismatch, unsafe run context and wrong credentials stop before network access', async t => {
  const {options, calls, root} = await fixture(t);
  await assert.rejects(verify({...options, candidate: Buffer.from('different')}), /Candidate checksum mismatch/);
  for (const patch of [
    {CM_BRANCH: 'main'},
    {CM_PULL_REQUEST_DEST: 'native-reach'},
    {REACH_RULES_PRIVATE_ARTIFACTS_CONFIRMED: ''},
    {REACH_STAGING_RULES_READER_JSON: ''},
    {REACH_STAGING_RULES_READER_JSON: JSON.stringify({...credential, project_id: 'production'})},
  ]) {
    await assert.rejects(verify({...options, env: {...env, ...patch}}));
  }
  assert.equal(calls.length, 0);
  assert.deepEqual(await readdir(root), []);
});

test('foreign rulesets, changed release pointer and multi-file sources produce no artifact', async t => {
  for (const change of [
    {first: {...release, rulesetName: 'projects/production/rulesets/fixture-1'}},
    {last: {...release, updateTime: '2026-11-07T22:31:00Z'}},
    {ruleset: {name: rulesetName, source: {files: [{content: 'a'}, {content: 'b'}]}}},
  ]) {
    const {root, options} = await fixture(t, change);
    await assert.rejects(verify(options));
    assert.deepEqual(await readdir(root), []);
  }
});
