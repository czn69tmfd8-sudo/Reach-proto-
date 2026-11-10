// Offline, review-only merge. Requires ACTUAL live staging rules exported by an authorized operator.
// Never fetches, deploys, or modifies Firebase resources.
import {readFile,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
const [firestorePath,storagePath,outPrefix] = process.argv.slice(2);
if (!firestorePath || !storagePath || !outPrefix) {
  throw Error('Usage: node merge-live-adventure-rules.mjs LIVE_FIRESTORE.rules LIVE_STORAGE.rules OUTPUT_PREFIX');
}
const read = p => readFile(p,'utf8');
const [firestore,storage,firestoreAddition,storageProposal] = await Promise.all([
  read(firestorePath),read(storagePath),read('adventure-book.proposed.rules'),read('adventure-book.storage.proposed.rules')
]);
const hash = s => createHash('sha256').update(s).digest('hex');
const end = /}\s*}\s*$/;
if (!firestore.includes('service cloud.firestore') || !end.test(firestore))
  throw Error('Live Firestore rules are not a recognizable complete Firestore ruleset');
if (!storage.includes('service firebase.storage') || !end.test(storage))
  throw Error('Live Storage rules are not a recognizable complete Storage ruleset');
if (!firestore.includes('nativeStaging') || !firestore.includes('pairInvites') || !firestore.includes('memberLocks'))
  throw Error('Live Firestore rules lack expected native staging pairing protections: manual review required');
if (firestore.includes('match /adventureBooks/{code}/memories/{memoryID}'))
  throw Error('Adventure Book Firestore match already exists: manual reconciliation required');
if (storage.includes('match /adventureBook/{code}/{memoryID}/{photoID}'))
  throw Error('Adventure Book Storage match already exists: manual reconciliation required');
if (!storageProposal.includes('match /b/{bucket}/o {') || !storageProposal.includes('match /adventureBook/{code}/{memoryID}/{photoID}'))
  throw Error('Storage proposal layout changed: manual review required');
// Extract the candidate Storage helper functions and match, excluding service-level wrappers.
// The proposal is NOT itself a replacement for the live ruleset.
const storageBodyStart = storageProposal.indexOf('match /b/{bucket}/o {') + 'match /b/{bucket}/o {'.length;
const storageBody = storageProposal.slice(storageBodyStart).replace(end,'').trim();
if (!storageBody.includes('function paired(code)') || !storageBody.includes('allow update, delete: if false;'))
  throw Error('Unexpected Storage proposal: manual review required');
const insert = (base,addition) => {
  const match = end.exec(base);
  return base.slice(0,match.index) + '\n    // BEGIN REVIEW-ONLY ADVENTURE BOOK ADDITION\n' +
    addition + '\n    // END REVIEW-ONLY ADVENTURE BOOK ADDITION\n' + base.slice(match.index);
};
const mergedFirestore = insert(firestore,firestoreAddition);
const mergedStorage = insert(storage,storageBody);
await writeFile(outPrefix+'.firestore.rules',mergedFirestore);
await writeFile(outPrefix+'.storage.rules',mergedStorage);
await writeFile(outPrefix+'.manifest.json',JSON.stringify({
  stagingProject:'reach-staging-a4745',reviewOnly:true,deployAuthorized:false,
  sourceFirestore:firestorePath,sourceStorage:storagePath,
  sha256:{liveFirestore:hash(firestore),liveStorage:hash(storage),
    mergedFirestore:hash(mergedFirestore),mergedStorage:hash(mergedStorage)},
  checks:['verify original rules unchanged except appended additions','run emulator tests',
    'independently review all existing storage matches and path collisions',
    'confirm Firebase project and bucket before any future approved deployment']
},null,2)+'\n');
console.log('Review-only candidates written. No Firebase connection or deployment occurred.');
