// Pure offline migration-model logic. No Firebase imports, network calls, or real-data access.
// WARNING: verifiedByTrustedBackend is a simulation fixture flag, NOT an authorization mechanism.
// Any actual production migration MUST independently verify approvals server-side.
export function validateRecovery(x){
 const e=[];if(!x||typeof x!=="object")return ["Missing request"];
 const p=x.pair||{},a=x.approval||{},locks=x.existingLocks||{};
 if(typeof x.pairCode!=="string"||!x.pairCode)e.push("Missing pair code");
 if(p.revoked===true)e.push("Revoked pairing");
 if(!p.hostUid||!p.partnerUid||p.hostUid===p.partnerUid)e.push("Invalid original member identities");
 if(!x.newHostUid||!x.newPartnerUid||x.newHostUid===x.newPartnerUid)e.push("Invalid new member identities");
 if([p.hostUid,p.partnerUid].includes(x.newHostUid)||[p.hostUid,p.partnerUid].includes(x.newPartnerUid))e.push("Recovery must not reuse a legacy identity");
 if(!a.hostVerified||!a.partnerVerified)e.push("Both partners must be independently verified");
 if(!Number.isFinite(a.now)||!Number.isFinite(a.expiresAt)||a.expiresAt<=a.now||a.expiresAt-a.now>15*60*1000)e.push("Approvals must be fresh and expire within 15 minutes");
 if(x.verifiedByTrustedBackend!==true)e.push("Trusted-backend verification is required");
 if(p.activeRoom!=null&&p.activeRoom!=="")e.push("Active room must end before recovery");
 if(p.openedBy!=null&&p.openedBy!=="")e.push("Room opener must be cleared before recovery");
 if(x.newHostUid&&Object.hasOwn(locks,x.newHostUid))e.push("New host already has a permanent lock");
 if(x.newPartnerUid&&Object.hasOwn(locks,x.newPartnerUid))e.push("New partner already has a permanent lock");
 if(p.profilePhotos!=null&&(typeof p.profilePhotos!=="object"||Array.isArray(p.profilePhotos)))e.push("Invalid photo map");
 return e;
}
export function simulateMigration(x){
 const errors=validateRecovery(x);if(errors.length)throw Error(errors.join("; "));
 const p=x.pair,photos={...(p.profilePhotos||{})};
 if(Object.hasOwn(photos,p.hostUid)){photos[x.newHostUid]=photos[p.hostUid];delete photos[p.hostUid];}
 if(Object.hasOwn(photos,p.partnerUid)){photos[x.newPartnerUid]=photos[p.partnerUid];delete photos[p.partnerUid];}
 return {pairCode:x.pairCode,pair:{...p,hostUid:x.newHostUid,partnerUid:x.newPartnerUid,profilePhotos:photos},
  proposedLocks:{[x.newHostUid]:{pairCode:x.pairCode},[x.newPartnerUid]:{pairCode:x.pairCode}},
  note:"DRY RUN ONLY: no records written; old locks require separate review; privileged transaction and audit log needed"};
}
export function runSelfTests(){
 const base=()=>({pairCode:"TEST",pair:{hostUid:"oldA",partnerUid:"oldB",activeRoom:null,openedBy:null,profilePhotos:{oldA:"A",oldB:"B"}},
 newHostUid:"newA",newPartnerUid:"newB",approval:{hostVerified:true,partnerVerified:true,now:100000,expiresAt:110000},existingLocks:{},verifiedByTrustedBackend:true});
 const cases=[
 ["valid pair preview",()=>{const x=base();const y=simulateMigration(x);return y.pair.profilePhotos.newA==="A"&&y.pair.profilePhotos.newB==="B"&&!Object.hasOwn(y.pair.profilePhotos,"oldA");}],
 ["unverified host rejected",()=>{const x=base();x.approval.hostVerified=false;return validateRecovery(x).length>0;}],
 ["unverified partner rejected",()=>{const x=base();x.approval.partnerVerified=false;return validateRecovery(x).length>0;}],
 ["expired approval rejected",()=>{const x=base();x.approval.expiresAt=99999;return validateRecovery(x).length>0;}],
 ["overlong approval rejected",()=>{const x=base();x.approval.expiresAt=1100000;return validateRecovery(x).length>0;}],
 ["revoked pair rejected",()=>{const x=base();x.pair.revoked=true;return validateRecovery(x).length>0;}],
 ["active room rejected",()=>{const x=base();x.pair.activeRoom="room";return validateRecovery(x).length>0;}],
 ["existing lock rejected",()=>{const x=base();x.existingLocks.newA={pairCode:"OTHER"};return validateRecovery(x).length>0;}],
 ["duplicate new identities rejected",()=>{const x=base();x.newPartnerUid="newA";return validateRecovery(x).length>0;}],
 ["missing trusted verification rejected",()=>{const x=base();x.verifiedByTrustedBackend=false;return validateRecovery(x).length>0;}],
 ["input not mutated",()=>{const x=base(),before=JSON.stringify(x);simulateMigration(x);return JSON.stringify(x)===before;}]
 ];
 return cases.map(([name,fn])=>{try{return{name,pass:fn()===true};}catch{return{name,pass:false};}});
}