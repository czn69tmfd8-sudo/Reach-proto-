import fs from "node:fs";
import assert from "node:assert/strict";
const root=fs.readFileSync("index.html","utf8");
const stage=fs.readFileSync("staging/index.html","utf8");
assert.match(root,/projectId:\s*"reach-prototype-d70ef"/);
assert.match(stage,/projectId:\s*"reach-staging-a4745"/);
assert.doesNotMatch(root,/\.\/staging\/reach2-(?:shell|features|date-ideas)\.(?:js|css)/);
for(const name of ["reach2-shell.js","reach2-features.js","reach2-date-ideas.js","reach2-shell.css","reach2-features.css"]){
 assert.ok(fs.existsSync("production-assets/"+name), "Missing production asset: "+name);
}
assert.match(stage,/reach2-kitchen\.js/);
console.log("REACH environment source checks passed (not a browser or Firebase integration test).");
