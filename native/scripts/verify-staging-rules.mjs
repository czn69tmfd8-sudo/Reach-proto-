import {createHash, sign} from 'node:crypto';
import {mkdir, readFile, writeFile} from 'node:fs/promises';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';

const project = 'reach-staging-a4745';
const releaseName = `projects/${project}/releases/cloud.firestore`;
const api = 'https://firebaserules.googleapis.com/v1/';
const tokenURL = 'https://oauth2.googleapis.com/token';
const rulesetPattern = /^projects\/reach-staging-a4745\/rulesets\/[A-Za-z0-9_-]+$/;
const timePattern = /^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d{1,9})?Z$/;
export const baselineSHA = '7e62b5e95f939d56155ce047634ead33023dfd1e6b35a6e20cb3601c7ddc00b8';
export const candidateSHA = 'ee7ee0ed97e3611aa41eeb7ebf9ba3f0d03fe5754de0171e3e88a3f64b588732';
const sha256 = value => createHash('sha256').update(value).digest('hex');
const encode = value => Buffer.from(JSON.stringify(value)).toString('base64url');

class VerificationError extends Error {}

async function requestJSON(fetcher, label, url, options) {
  let response;
  try {
    response = await fetcher(url, {...options, redirect: 'error', signal: AbortSignal.timeout(20000)});
  } catch {
    throw new VerificationError(`${label} request failed or timed out.`);
  }
  if (!response.ok) throw new VerificationError(`${label} returned HTTP ${response.status}.`);
  try {
    return await response.json();
  } catch {
    throw new VerificationError(`${label} did not return valid JSON.`);
  }
}

async function accessToken(fetcher, secret) {
  if (!secret) throw new VerificationError('Missing REACH_STAGING_RULES_READER_JSON.');
  let assertion;
  try {
    const key = JSON.parse(secret);
    if (key.type !== 'service_account' || key.project_id !== project ||
        key.client_email !== `reach-rules-reader@${project}.iam.gserviceaccount.com`) {
      throw new Error();
    }
    const now = Math.floor(Date.now() / 1000);
    const payload = encode({
      iss: key.client_email, aud: tokenURL, iat: now, exp: now + 300,
      scope: 'https://www.googleapis.com/auth/firebase.readonly',
    });
    const message = `${encode({alg: 'RS256', typ: 'JWT'})}.${payload}`;
    assertion = `${message}.${sign('RSA-SHA256', Buffer.from(message), key.private_key).toString('base64url')}`;
  } catch {
    throw new VerificationError('Credential must be a valid JSON key for the dedicated staging rules reader.');
  }
  const token = await requestJSON(fetcher, 'Google OAuth', tokenURL, {
    method: 'POST',
    body: new URLSearchParams({grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion}),
  });
  if (typeof token?.access_token !== 'string' || !/^[A-Za-z0-9._~+\/=-]+$/.test(token.access_token)) {
    throw new VerificationError('Google OAuth did not return a usable access token.');
  }
  return token.access_token;
}

export async function verify({env, candidate, output, fetcher = fetch}) {
  if (env.CM_BRANCH !== 'native-reach' || env.CM_PULL_REQUEST_DEST) {
    throw new VerificationError('Only a native-reach branch build may verify staging rules.');
  }
  if (env.REACH_RULES_PRIVATE_ARTIFACTS_CONFIRMED !== 'yes') {
    throw new VerificationError('Confirm private Codemagic artifact access before running.');
  }
  const candidateHash = sha256(candidate);
  if (candidateHash !== candidateSHA) {
    throw new VerificationError(`Candidate checksum mismatch: ${candidateHash}. Expected ${candidateSHA}.`);
  }
  const token = await accessToken(fetcher, env.REACH_STAGING_RULES_READER_JSON);
  const get = (label, name) => requestJSON(fetcher, label, api + name, {
    method: 'GET', headers: {Authorization: `Bearer ${token}`},
  });
  const release = await get('Active release', releaseName);
  if (![releaseName, releaseName + '/(default)'].includes(release?.name) ||
      !rulesetPattern.test(release.rulesetName) || !timePattern.test(release.updateTime)) {
    throw new VerificationError('Unexpected staging release metadata.');
  }
  const ruleset = await get('Referenced ruleset', release.rulesetName);
  const files = ruleset?.source?.files;
  if (ruleset?.name !== release.rulesetName || !Array.isArray(files) || files.length !== 1 ||
      typeof files[0]?.content !== 'string' || files[0].content.length === 0) {
    throw new VerificationError('Unexpected ruleset or source file layout.');
  }
  const latest = await get('Release consistency check', releaseName);
  if (latest?.name !== release.name || latest.rulesetName !== release.rulesetName ||
      latest.updateTime !== release.updateTime) {
    throw new VerificationError('The active release changed during readback. Run verification again.');
  }
  const source = Buffer.from(files[0].content, 'utf8');
  const activeHash = sha256(source);
  const report = {
    project, database: '(default)', releaseName: release.name,
    rulesetName: release.rulesetName, updateTime: release.updateTime,
    activeSHA256: activeHash, expectedBaselineSHA256: baselineSHA, candidateSHA256: candidateHash,
    result: activeHash === baselineSHA ? 'verified' : 'release-hold',
  };
  await mkdir(output, {mode: 0o700});
  await writeFile(resolve(output, 'active.rules'), source, {mode: 0o600, flag: 'wx'});
  await writeFile(resolve(output, 'verification.json'), JSON.stringify(report, null, 2) + '\n',
    {mode: 0o600, flag: 'wx'});
  return report;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    const candidate = await readFile(new URL('../firebase/reviews/staging-relationship-space/merged.rules', import.meta.url));
    const report = await verify({env: process.env, candidate, output: 'native/build/staging-rules-verification'});
    console.log(JSON.stringify(report, null, 2));
    if (report.result !== 'verified') {
      console.error('RELEASE HOLD: live staging rules differ from the reviewed baseline.');
      process.exitCode = 1;
    }
  } catch (error) {
    const reason = error instanceof VerificationError ? error.message : 'Unexpected verification or artifact error.';
    console.error(`RELEASE HOLD: ${reason}`);
    process.exitCode = 1;
  }
}
