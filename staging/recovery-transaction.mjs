// Staging-only server-side recovery transaction engine. Requires Admin Firestore SDK injected by caller.
// Not deployed. Authorization MUST be checked before this function is invoked.
export async function commitApprovedRecovery({db,challengeId,now=Date.now()}){
 if(!db || !challengeId || typeof challengeId!=="string")throw Error("Invalid invocation");
 const challengeRef=db.collection("recoveryChallenges").doc(challengeId);
 return db.runTransaction(async tx=>{
  const challengeSnap=await tx.get(challengeRef);
  if(!challengeSnap.exists)throw Error("Challenge missing");
  const c=challengeSnap.data();
  if(c.status!=="approved"||c.consumedAt)throw Error("Challenge not approved or already consumed");
  if(!Number.isFinite(c.createdAtMs)||!Number.isFinite(c.expiresAtMs)||c.expiresAtMs<=now||c.createdAtMs>now||c.expiresAtMs-c.createdAtMs>900000)throw Error("Challenge expired or invalid");
  if(!c.hostApproval || !c.partnerApproval || c.hostApproval.challengeId!==challengeId || c.partnerApproval.challengeId!==challengeId || c.hostApproval.principal!==c.oldHostPrincipal || c.partnerApproval.principal!==c.oldPartnerPrincipal)throw Error("Independent approvals missing");
  if(!c.hostApproval.verifiedAtMs||!c.partnerApproval.verifiedAtMs||Math.min(c.hostApproval.verifiedAtMs,c.partnerApproval.verifiedAtMs)<c.createdAtMs||Math.max(c.hostApproval.verifiedAtMs,c.partnerApproval.verifiedAtMs)>now)throw Error("Invalid approval time");
  const ids=[c.oldHostUid,c.oldPartnerUid,c.newHostUid,c.newPartnerUid];
  if(ids.some(x=>typeof x!=="string"||!x)||new Set(ids).size!==4)throw Error("Distinct identities required");
  if(typeof c.pairCode!=="string"||!c.pairCode)throw Error("Pair missing");
  const pairRef=db.collection("pairInvites").doc(c.pairCode);
  const newHostLock=db.collection("memberLocks").doc(c.newHostUid);
  const newPartnerLock=db.collection("memberLocks").doc(c.newPartnerUid);
  const auditRef=db.collection("recoveryAudit").doc(challengeId);
  // All transaction reads precede writes.
  const [pairSnap,hostLockSnap,partnerLockSnap,auditSnap]=await Promise.all([tx.get(pairRef),tx.get(newHostLock),tx.get(newPartnerLock),tx.get(auditRef)]);
  if(!pairSnap.exists)throw Error("Pair missing");
  const p=pairSnap.data();
  if(p.hostUid!==c.oldHostUid||p.partnerUid!==c.oldPartnerUid||p.revoked===true)throw Error("Pair changed or revoked");
  if((p.activeRoom!==null&&p.activeRoom!==""&&p.activeRoom!==undefined)||(p.openedBy!==null&&p.openedBy!==""&&p.openedBy!==undefined))throw Error("Active session present");
  if(hostLockSnap.exists||partnerLockSnap.exists||auditSnap.exists)throw Error("Lock or audit conflict");
  const photos={...(p.profilePhotos||{})};
  if(Object.hasOwn(photos,c.oldHostUid)){photos[c.newHostUid]=photos[c.oldHostUid];delete photos[c.oldHostUid];}
  if(Object.hasOwn(photos,c.oldPartnerUid)){photos[c.newPartnerUid]=photos[c.oldPartnerUid];delete photos[c.oldPartnerUid];}
  const stamp=new Date(now);
  tx.create(newHostLock,{pairCode:c.pairCode,createdAt:stamp});
  tx.create(newPartnerLock,{pairCode:c.pairCode,createdAt:stamp});
  tx.update(pairRef,{hostUid:c.newHostUid,partnerUid:c.newPartnerUid,profilePhotos:photos});
  tx.update(challengeRef,{status:"consumed",consumedAt:stamp});
  tx.create(auditRef,{pairCode:c.pairCode,challengeId,oldHostUid:c.oldHostUid,oldPartnerUid:c.oldPartnerUid,newHostUid:c.newHostUid,newPartnerUid:c.newPartnerUid,committedAt:stamp});
  return {ok:true,pairCode:c.pairCode};
 });
}
