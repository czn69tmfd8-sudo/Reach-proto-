import {readFile,writeFile} from 'node:fs/promises';
const base=await readFile('reviews/staging-relationship-space/merged.rules','utf8');
const addition=await readFile('adventure-book.proposed.rules','utf8');
if(!base.endsWith('}\n}\n')) throw Error('Unexpected base rule layout');
await writeFile('adventure-book.combined.generated.rules',base.slice(0,-4)+addition+'\n}\n}\n');
