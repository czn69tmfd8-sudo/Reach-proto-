// Run with: node --test staging/recovery-transaction.test.mjs
// Offline tests: no Firebase credentials, network calls or production data.
import test from 'node:test';
import assert from 'node:assert/strict';
import {commitApprovedRecovery} from './recovery-transaction.mjs';

const NOW=1760000000000;
function fixture(){
 const challengeId='test-challenge';
 const pairCode='TESTPAIR';
 const c={status:'approved',createdAtMs:NOW-60000,expiresAtMs:NOW+60000,
 oldHostPrincipal:'host-principal',oldPartnerPrincipal:'partner-principal',
 hostApproval:{challengeId,principal:'host-principal',verifiedAtMs:NOW-30000},
 partnerApproval:{challengeId,principal:'partner-principal',verifiedAtMs:NOW-20000},
 oldHostUid:'old-host',oldPartnerUid:'old-partner',newHostUid:'new-host',newPartnerUid:'new-partner',pairCode};
 const pair={hostUid:'old-host',partnerUid:'old-partner',activeRoom:'',openedBy:'',profilePhotos:{'old-host':'host-photo','old-partner':'partner-photo'}};
 return {challengeId,c,pair};
}
function fakeDb({c,pair,challengeId='test-challenge'}){
 const records=new Map([['recoveryChallenges/'+challengeId,structuredClone(c)],['pairInvites/TESTPAIR',structuredClone(pair)]]);
 const db={collection(name){return {doc(id){return {path:name+'/'+id}}}},async runTransaction(fn){
  const pending=[];
  const tx={
   async get(ref){const value=records.get(ref.path);return {exists:value!==undefined,data:()=>structuredClone(value)}},
   create(ref,value){pending.push(['create',ref.path,value])},
   update(ref,value){pending.push(['update',ref.path,value])}
  };
  const result=await fn(tx);
  // Reject invalid creates before any writes (transactional test double).
  for(const [op,path] of pending)if(op==='create'&&records.has(path))throw Error('Already exists');
  for(const [op,path,value] of pending)records.set(path,op==='update'?{...records.get(path),...structuredClone(value)}:structuredClone(value));
  return result;
 }};
 return {db,records};
}
test('successful recovery atomically remaps photos, locks, audit and consumes challenge',async()=>{
 const x=fixture(),f=fakeDb(x);
 const result=await commitApprovedRecovery({db:f.db,challengeId:x.challengeId,now:NOW});
 assert.equal(result.ok,true);
 const pair=f.records.get('pairInvites/TESTPAIR');
 assert.equal(pair.hostUid,'new-host');
 assert.equal(pair.partnerUid,'new-partner');
 assert.deepEqual(pair.profilePhotos,{'new-host':'host-photo','new-partner':'partner-photo'});
 assert.equal(f.records.get('memberLocks/new-host').pairCode,'TESTPAIR');
 assert.equal(f.records.get('memberLocks/new-partner').pairCode,'TESTPAIR');
 assert.equal(f.records.get('recoveryChallenges/test-challenge').status,'consumed');
 assert.equal(f.records.get('recoveryAudit/test-challenge').pairCode,'TESTPAIR');
 await assert.rejects(commitApprovedRecovery({db:f.db,challengeId:x.challengeId,now:NOW}),/already consumed/);
});
for(const [name,change,error] of [
 ['missing host approval',x=>{x.c.hostApproval=null},/approvals missing/],
 ['expired challenge',x=>{x.c.expiresAtMs=NOW-1},/expired/],
 ['wrong approval principal',x=>{x.c.partnerApproval.principal='intruder'},/approvals missing/],
 ['revoked pair',x=>{x.pair.revoked=true},/revoked/],
 ['active room',x=>{x.pair.activeRoom='room1'},/Active session/],
 ['duplicate identity',x=>{x.c.newPartnerUid='new-host'},/Distinct identities/],
 ['stale pair identity',x=>{x.pair.hostUid='someone-else'},/Pair changed/]
]){
 test(name+' fails closed with no writes',async()=>{
  const x=fixture();change(x);const f=fakeDb(x),before=structuredClone([...f.records]);
  await assert.rejects(commitApprovedRecovery({db:f.db,challengeId:x.challengeId,now:NOW}),error);
  assert.deepEqual([...f.records],before);
 });
}
test('preexisting target lock blocks all writes',async()=>{
 const x=fixture(),f=fakeDb(x);
 f.records.set('memberLocks/new-host',{pairCode:'OTHER'});
 const before=structuredClone([...f.records]);
 await assert.rejects(commitApprovedRecovery({db:f.db,challengeId:x.challengeId,now:NOW}),/Lock or audit conflict/);
 assert.deepEqual([...f.records],before);
});
