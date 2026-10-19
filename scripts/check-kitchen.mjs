import fs from "node:fs";
import assert from "node:assert/strict";
const feature = fs.readFileSync("staging/reach2-features.js","utf8");
const kitchen = fs.readFileSync("staging/reach2-kitchen.js","utf8");
const shell = fs.readFileSync("staging/reach2-shell.js","utf8");
assert.match(shell,/data-rk-entry/);
assert.match(kitchen,/existing\.onclick=home/);
assert.match(feature,/data-rk-entry/, "Feature tile binding must skip the Kitchen-owned tile");
console.log("Kitchen tile ownership source checks passed");
