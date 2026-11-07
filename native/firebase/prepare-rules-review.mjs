// Local review preparation only. This module has no Firebase or deployment API.
import {createHash} from 'node:crypto';
import {readFile, mkdir, mkdtemp, writeFile, rename, rm, lstat} from 'node:fs/promises';
import {dirname, resolve, join} from 'node:path';
import {pathToFileURL} from 'node:url';

export const stagingProject = 'reach-staging-a4745';
export const sha256 = text => createHash('sha256').update(text).digest('hex');

// Keep offsets intact while excluding comments/strings from structural inspection.
function mask(source) {
 let output='', i=0;
 while(i<source.length) {
  const start=i;
  if(source.startsWith('//',i)) {
   while(i<source.length && source[i]!=='\n')i++;
  } else if(source.startsWith('/*',i)) {
   const end=source.indexOf('*/',i+2);
   if(end<0)throw Error('Unterminated rules comment');
   i=end+2;
  } else if(source[i]==="'" || source[i]==='"') {
   const quote=source[i++];let closed=false;
   while(i<source.length) {
    if(source[i]==='\\'){i+=2;continue}
    if(source[i++]===quote){closed=true;break}
   }
   if(!closed)throw Error('Unterminated rules string');
  } else {output+=source[i++];continue}
  output+=source.slice(start,i).replace(/[^\n]/g,' ');
 }
 return output;
}
function closeBrace(masked, open) {
 let depth=0;
 for(let i=open;i<masked.length;i++) {
  if(masked[i]==='{')depth++;
  if(masked[i]==='}' && --depth===0)return i;
 }
 throw Error('Incomplete rules block');
}
function parse(source) {
 const code=mask(source);let balance=0;
 for(const c of code){if(c==='{')balance++;if(c==='}' && --balance<0)throw Error('Unexpected rules closing brace')}
 if(balance!==0)throw Error('Incomplete rules: unbalanced braces');
 const versions=[...code.matchAll(/\brules_version\s*=[^;]+;/g)];
 if(versions.length!==1 || code.slice(0,versions[0].index).trim() || !/^rules_version\s*=\s*['"]2['"]\s*;$/.test(source.slice(versions[0].index,versions[0].index+versions[0][0].length)))throw Error('Only explicit rules_version 2 is supported');
 if((code.match(/\bservice\s+cloud\.firestore\s*\{/g)||[]).length!==1)throw Error('Expected one Firestore service');
 const matches=[...code.matchAll(/\bmatch\s+(\S+)\s*\{/g)].map(m=>({path:m[1],start:m.index,open:m.index+m[0].length-1}));
 for(const m of matches)m.close=closeBrace(code,m.open);
 const roots=matches.filter(m=>m.path==='/databases/{database}/documents');
 if(roots.length!==1)throw Error('Expected one documents root with database variable named database');
 const root=roots[0];
 if(matches.some(m=>m!==root && (m.start<root.open || m.close>root.close)))throw Error('Unsupported match outside documents root');
 return {code,matches,root};
}
export function buildAdditiveRules(baseline,nativeRules,{project,expectedBaselineSHA}={}) {
 if(project!==stagingProject)throw Error('Only reach-staging-a4745 review preparation is allowed');
 if(!expectedBaselineSHA || sha256(baseline)!==expectedBaselineSHA)throw Error('Baseline SHA-256 does not match the supplied full source');
 const base=parse(baseline),native=parse(nativeRules);
 if(base.matches.some(m=>m.path.startsWith('/nativeStaging')))throw Error('Baseline already has a nativeStaging match; manual review required');
 const top=base.matches.filter(m=>m!==base.root && !base.matches.some(p=>p!==base.root && p!==m && p.open<m.start && p.close>m.close));
 for(const m of top) {
  // Dynamic root paths can overlap nativeStaging. Even function-based grants
  // need a human review; a sibling allow overrides a stricter native rule.
  if(m.path.startsWith('/{')) {
   const body=base.code.slice(m.open+1,m.close);
   const grants=[...body.matchAll(/\ballow\b[^;]*;/g)];
   if(grants.some(g=>!/:\s*if\s+false\s*;\s*$/.test(g[0])))throw Error('Broad dynamic-root grant may override native authorization; manual review required');
  }
 }
 let rootBody=base.code.slice(base.root.open+1,base.root.close);
 for(const m of [...top].sort((a,b)=>b.start-a.start)) {
  const start=m.start-base.root.open-1,end=m.close-base.root.open;
  rootBody=rootBody.slice(0,start)+' '.repeat(end-start)+rootBody.slice(end);
 }
 if(/\ballow\b/.test(rootBody))throw Error('Grant on documents root requires manual review');
 const blocks=native.matches.filter(m=>m.path==='/nativeStaging/v1');
 if(blocks.length!==1)throw Error('Expected exactly one nativeStaging/v1 block');
 const block=blocks[0];
 if(native.matches.some(m=>m!==native.root && m!==block && (m.start<block.open || m.close>block.close)))throw Error('Native candidate contains matches outside nativeStaging/v1');
 if((native.code.slice(native.root.open+1,block.start)+native.code.slice(block.close+1,native.root.close)).trim())throw Error('Native candidate contains code outside its block');
 const fragment=nativeRules.slice(block.start,block.close+1);
 const insertion='\n  // BEGIN REACH native staging v1 — review required; not deployment approval\n  '+fragment+'\n  // END REACH native staging v1\n';
 const merged=baseline.slice(0,base.root.close)+insertion+baseline.slice(base.root.close);
 // Every original byte remains in order; no legacy clause is rewritten.
 if(merged.slice(0,base.root.close)+merged.slice(base.root.close+insertion.length)!==baseline)throw Error('Baseline preservation failed');
 return {merged,insertion,manifest:{project,baselineSHA256:sha256(baseline),nativeSHA256:sha256(nativeRules),mergedSHA256:sha256(merged),deploymentApproved:false,liveBaselineVerified:false}};
}
export function buildRelationshipReview(baseline, proposal) {
 const baselineSHA256 = '7e62b5e95f939d56155ce047634ead33023dfd1e6b35a6e20cb3601c7ddc00b8';
 if(sha256(baseline)!==baselineSHA256)throw Error('Staging reference changed; review the new baseline before merging');
 const base=parse(baseline), sharing=parse(proposal);
 const path='/nativeStaging/v1/relationshipSpace/{code}/entries/{entryID}';
 const [match,...extra]=sharing.matches.filter(m=>m!==sharing.root);
 if(match?.path!==path || extra.length)throw Error('Expected only the isolated relationshipSpace match');
 const helperCode=sharing.code.slice(sharing.root.open+1,match.start);
 if(/\ballow\b/.test(helperCode) || sharing.code.slice(match.close+1,sharing.root.close).trim())throw Error('Unexpected code outside the sharing match');
 for(const helper of helperCode.matchAll(/\bfunction\s+(\w+)/g)) {
  if(!helper[1].startsWith('space') || new RegExp('\\bfunction\\s+'+helper[1]+'\\b').test(base.code)) {
   throw Error('Unexpected or colliding sharing helper: '+helper[1]);
  }
 }
 const insertion='\n  // BEGIN REACH relationship space pilot — review only\n'
  +proposal.slice(sharing.root.open+1,sharing.root.close).trimEnd()
  +'\n  // END REACH relationship space pilot\n';
 const merged=baseline.slice(0,base.root.close)+insertion+baseline.slice(base.root.close);
 parse(merged);
 return {merged,insertion,manifest:{
  project:stagingProject,database:'(default)',baselineSHA256,proposalSHA256:sha256(proposal),
  mergedSHA256:sha256(merged),liveBaselineVerified:false,deploymentApproved:false
 }};
}

const relationshipReviewDir=new URL('./reviews/staging-relationship-space/',import.meta.url);
export async function relationshipReview() {
 const [baseline,proposal]=await Promise.all([
  readFile(new URL('./reviews/staging-2026-11-06-hardened/merged.rules',import.meta.url),'utf8'),
  readFile(new URL('../sync-proposal/relationship-space.proposed.rules',import.meta.url),'utf8')
 ]);
 return buildRelationshipReview(baseline,proposal);
}
export async function readRelationshipReview() {
 const expected=await relationshipReview();
 const [merged,manifest]=await Promise.all([
  readFile(new URL('merged.rules',relationshipReviewDir),'utf8'),
  readFile(new URL('review.json',relationshipReviewDir),'utf8').then(JSON.parse)
 ]);
 if(merged!==expected.merged || JSON.stringify(manifest)!==JSON.stringify(expected.manifest)) {
  throw Error('Relationship review artifact does not match the exact additive merge');
 }
 return merged;
}
export async function rulesForRegression(baseline) {
 return process.env.REACH_SHARED_MERGED==='1' ? readRelationshipReview() : baseline;
}
async function writeRelationshipReview() {
 const {merged,manifest}=await relationshipReview();
 await mkdir(relationshipReviewDir,{recursive:true});
 await writeFile(new URL('merged.rules',relationshipReviewDir),merged);
 await writeFile(new URL('review.json',relationshipReviewDir),JSON.stringify(manifest,null,2)+'\n');
 return manifest;
}
export async function prepareReview({baselinePath,nativePath,outputDirectory,project,expectedBaselineSHA}) {
 const baseline=await readFile(baselinePath,'utf8'),native=await readFile(nativePath,'utf8');
 const review=buildAdditiveRules(baseline,native,{project,expectedBaselineSHA});
 const destination=resolve(outputDirectory);
 try {await lstat(destination);throw Error('Review output already exists; refusing overwrite')}
 catch(error){if(error.code!=='ENOENT')throw error}
 await mkdir(dirname(destination),{recursive:true});
 const temporary=await mkdtemp(join(dirname(destination),'.reach-review-'));
 try {
  await writeFile(join(temporary,'baseline.rules'),baseline,{flag:'wx'});
  await writeFile(join(temporary,'merged.rules'),review.merged,{flag:'wx'});
  await writeFile(join(temporary,'native-addition.rules'),review.insertion,{flag:'wx'});
  await writeFile(join(temporary,'review.json'),JSON.stringify(review.manifest,null,2)+'\n',{flag:'wx'});
  await rename(temporary,destination);
 } catch(error){await rm(temporary,{recursive:true,force:true});throw error}
 return review.manifest;
}
// Load an exact prepared artifact for emulator testing; no approval is inferred.
export async function readReview(directory,nativeRules) {
 const baseline=await readFile(join(directory,'baseline.rules'),'utf8');
 const merged=await readFile(join(directory,'merged.rules'),'utf8');
 const manifest=JSON.parse(await readFile(join(directory,'review.json'),'utf8'));
 const expected=buildAdditiveRules(baseline,nativeRules,{project:manifest.project,expectedBaselineSHA:manifest.baselineSHA256});
 if(manifest.nativeSHA256!==sha256(nativeRules) || manifest.mergedSHA256!==sha256(merged) || expected.merged!==merged)throw Error('Review artifact changed or does not match the current native candidate');
 return merged;
}
if(process.argv[1] && import.meta.url===pathToFileURL(resolve(process.argv[1])).href) {
 try {
  const args=process.argv.slice(2);
  if(args.length===1 && args[0]==='--prepare-relationship-review') {
   console.log(JSON.stringify(await writeRelationshipReview(),null,2));
  } else {
   if(args.length!==6)throw Error('Usage: node prepare-rules-review.mjs BASELINE NATIVE OUTPUT_DIR PROJECT EXPECTED_SHA256 --review-only');
   if(args[5]!=='--review-only')throw Error('Only review-only mode is supported');
   console.log(JSON.stringify(await prepareReview({baselinePath:args[0],nativePath:args[1],outputDirectory:args[2],project:args[3],expectedBaselineSHA:args[4]}),null,2));
  }
 } catch(error){console.error(error.message);process.exitCode=1}
}
