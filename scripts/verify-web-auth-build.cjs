// Release gate: inspect public compiled output only, never configuration secrets.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const build = path.resolve(process.argv[2] || 'build/web');
const bundle = fs.readFileSync(fs.statSync(build).isFile() ? build : path.join(build, 'main.dart.js'), 'utf8');
const ids = [...new Set(bundle.match(/\d+-[A-Za-z0-9_-]+\.apps\.googleusercontent\.com/g) || [])];
assert(ids.length > 0, 'Release has no public Google OAuth Client ID; Google sign-in will fail');
console.log(JSON.stringify({ status: 'PASS', googleClientIdPresent: true, bundleBytes: Buffer.byteLength(bundle) }));
