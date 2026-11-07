// Verify the registrant belonging to the exact compiled web output, not an old cache.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');

function verifyRegistrant(source, plugins) {
  const missingImports = plugins.filter(name => !source.includes(`package:${name}/`));
  assert.equal(missingImports.length, 0, `Web registrant is missing: ${missingImports.join(', ')}. Run flutter clean, flutter pub get, then rebuild.`);
  const calls = [...source.matchAll(/(\w+)\.registerWith\(registrar\)/g)].map(match => match[1]);
  assert(new Set(calls).size >= plugins.length, 'Web plugin registration calls are incomplete');
  assert(source.includes('registrar.registerMessageHandler()'), 'Web plugin message handler is missing');
  return calls;
}

function verifyBuild(build, project = path.resolve(__dirname, '..')) {
  const digest = data => crypto.createHash('sha256').update(data).digest('hex');
  const bundleHash = digest(fs.readFileSync(path.join(build, 'main.dart.js')));
  const cacheRoot = path.join(project, '.dart_tool', 'flutter_build');
  const matches = fs.readdirSync(cacheRoot, {withFileTypes:true})
    .filter(entry => entry.isDirectory())
    .map(entry => path.join(cacheRoot, entry.name))
    .filter(dir => fs.existsSync(path.join(dir, 'main.dart.js')) && digest(fs.readFileSync(path.join(dir, 'main.dart.js'))) === bundleHash);
  assert(matches.length > 0, 'No compiler cache matches this web bundle; plugin registration cannot be verified');
  const pluginNames = JSON.parse(fs.readFileSync(path.join(project, '.flutter-plugins-dependencies'), 'utf8')).plugins.web.map(plugin => plugin.name);
  assert(pluginNames.length > 0, 'Web dependency metadata is missing');
  for (const dir of matches) {
    const entrypoint = fs.readFileSync(path.join(dir, 'main.dart'), 'utf8');
    assert(entrypoint.includes('pluginRegistrant.registerPlugins()'), 'Compiled entrypoint does not initialize web plugins');
    const registered = verifyRegistrant(fs.readFileSync(path.join(dir, 'web_plugin_registrant.dart'), 'utf8'), pluginNames);
    assert(registered.length >= pluginNames.length);
  }
  return {status:'PASS', expectedWebPlugins:pluginNames.length, matchedCompilerCaches:matches.length, bundleSha256:bundleHash};
}

module.exports = {verifyRegistrant, verifyBuild};
if (require.main === module) console.log(JSON.stringify(verifyBuild(path.resolve(process.argv[2] || 'build/web'))));
