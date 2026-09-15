#!/usr/bin/env node
import { spawn } from 'node:child_process';
import { promises as fs, existsSync, readdirSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = path.resolve(SCRIPT_DIR, '..');
const BACKEND_DIR = path.join(PROJECT_ROOT, 'backend');
const BACKEND_TEST_DIR = path.join(BACKEND_DIR, 'test');
const LOCAL_LOGS_BASE = path.join(PROJECT_ROOT, 'BA_DOCUMENTS', 'FULL_APP_TEST_20260914', 'local');
const ISOLATION_PRELOAD = path.join(PROJECT_ROOT, 'scripts', 'test-isolation.cjs');

const COMSPEC = process.env.ComSpec || 'C:\\Windows\\System32\\cmd.exe';

// Safe environment allowlist for child execution (no credentials / DB urls leaked)
function buildSanitizedEnv(isBackendTest = false) {
  const allowedKeys = [
    'PATH',
    'Path',
    'SystemRoot',
    'WINDIR',
    'ComSpec',
    'TEMP',
    'TMP',
    'USERPROFILE',
    'APPDATA',
    'LOCALAPPDATA',
    'NUMBER_OF_PROCESSORS',
    'PROCESSOR_ARCHITECTURE',
    'SYSTEMDRIVE',
    'ProgramFiles',
    'ProgramFiles(x86)',
    'ProgramW6432',
    'PROGRAMFILES',
    'PROGRAMFILES(X86)',
    'PROGRAMW6432',
  ];

  const env = {};
  for (const key of allowedKeys) {
    if (process.env[key] !== undefined) {
      env[key] = process.env[key];
    }
  }

  if (isBackendTest) {
    env.NODE_ENV = 'test';
    env.ACCESS_TOKEN_SECRET = 'dummy-test-access-token-secret-at-least-32-bytes-long';
    env.REFRESH_TOKEN_SECRET = 'dummy-test-refresh-token-secret-at-least-32-bytes-long';
    env.OTP_SECRET = 'dummy-test-otp-secret-at-least-32-bytes-long';
    env.JWT_SECRET = 'dummy-test-access-token-secret-at-least-32-bytes-long';
    env.CLOUDINARY_CLOUD_NAME = 'demo';
  }

  return env;
}

function checkPrerequisites() {
  const dartToolConfig = path.join(PROJECT_ROOT, '.dart_tool', 'package_config.json');
  const backendNodeModules = path.join(PROJECT_ROOT, 'backend', 'node_modules');

  return {
    hasFlutterDeps: existsSync(dartToolConfig),
    hasBackendDeps: existsSync(backendNodeModules),
  };
}

function getEnumeratedBackendTests() {
  if (!existsSync(BACKEND_TEST_DIR)) {
    throw new Error(`Backend test directory not found: ${BACKEND_TEST_DIR}`);
  }
  const files = readdirSync(BACKEND_TEST_DIR)
    .filter((file) => file.endsWith('.test.js'))
    .sort();

  if (files.length === 0) {
    throw new Error('No .test.js files found in backend/test');
  }

  return files.map((file) => path.join('test', file).replace(/\\/g, '/'));
}

function buildCommandInventory() {
  const backendTests = getEnumeratedBackendTests();

  return [
    {
      id: '01_dart_format',
      name: 'Flutter / Dart Format Check',
      type: 'comspec',
      command: 'D:/flutter/bin/dart.bat format --output=none --set-exit-if-changed lib test',
      executable: COMSPEC,
      args: ['/d', '/s', '/c', 'D:/flutter/bin/dart.bat format --output=none --set-exit-if-changed lib test'],
      cwd: PROJECT_ROOT,
      env: buildSanitizedEnv(false),
      prereq: 'hasFlutterDeps',
      prereqDesc: '.dart_tool/package_config.json',
      independent: true,
    },
    {
      id: '02_flutter_analyze',
      name: 'Flutter Static Analysis (--no-pub)',
      type: 'comspec',
      command: 'D:/flutter/bin/flutter.bat analyze --no-pub',
      executable: COMSPEC,
      args: ['/d', '/s', '/c', 'D:/flutter/bin/flutter.bat analyze --no-pub'],
      cwd: PROJECT_ROOT,
      env: buildSanitizedEnv(false),
      prereq: 'hasFlutterDeps',
      prereqDesc: '.dart_tool/package_config.json',
      independent: true,
    },
    {
      id: '03_flutter_test',
      name: 'Flutter Unit & Widget Tests (--no-pub)',
      type: 'comspec',
      command: 'D:/flutter/bin/flutter.bat test --no-pub',
      executable: COMSPEC,
      args: ['/d', '/s', '/c', 'D:/flutter/bin/flutter.bat test --no-pub'],
      cwd: PROJECT_ROOT,
      env: buildSanitizedEnv(false),
      prereq: 'hasFlutterDeps',
      prereqDesc: '.dart_tool/package_config.json',
      independent: true,
    },
    {
      id: '04_backend_build',
      name: 'Backend TypeScript Build',
      type: 'comspec',
      command: 'npm.cmd --prefix backend run build',
      executable: COMSPEC,
      args: ['/d', '/s', '/c', 'npm.cmd --prefix backend run build'],
      cwd: PROJECT_ROOT,
      env: buildSanitizedEnv(false),
      prereq: 'hasBackendDeps',
      prereqDesc: 'backend/node_modules',
      independent: true,
    },
    {
      id: '05_backend_lint',
      name: 'Backend ESLint',
      type: 'comspec',
      command: 'npm.cmd --prefix backend run lint',
      executable: COMSPEC,
      args: ['/d', '/s', '/c', 'npm.cmd --prefix backend run lint'],
      cwd: PROJECT_ROOT,
      env: buildSanitizedEnv(false),
      prereq: 'hasBackendDeps',
      prereqDesc: 'backend/node_modules',
      independent: true,
    },
    {
      id: '06_backend_unit_tests',
      name: `Backend Node Unit Tests with Isolation (${backendTests.length} suites)`,
      type: 'node',
      command: `node --require "${ISOLATION_PRELOAD}" --test ${backendTests.join(' ')}`,
      executable: process.execPath,
      args: ['--require', ISOLATION_PRELOAD, '--test', ...backendTests],
      cwd: BACKEND_DIR,
      env: buildSanitizedEnv(true),
      prereq: 'hasBackendDeps',
      prereqDesc: 'backend/node_modules',
      independent: false,
      dependsOn: '04_backend_build',
    },
  ];
}

function printHelp() {
  process.stdout.write(`Full Verification Harness - StockManagementAndTaxWarning

Usage:
  node scripts/run-full-verification.mjs [run]
  node scripts/run-full-verification.mjs flutter-test
  node scripts/run-full-verification.mjs --prepare
  node scripts/run-full-verification.mjs --help

Options:
  run             Execute the fixed suite sequentially and record incremental evidence (default).
  flutter-test    Execute only step 03_flutter_test (Flutter unit & widget tests) without re-running passed steps, saving to a new run directory.
  --prepare       Validate fixed command inventory, prerequisites, and isolation without executing.
  --help, -h      Show this help message without modifying filesystem.

Safety & Isolation Guarantees:
  - Process-level test isolation preload: scripts/test-isolation.cjs intercepts dotenv to no-op and blocks live sockets/TLS/HTTP/outbound fetch.
  - Dependency-free Node script using child_process.spawn with shell: false and windowsHide: true.
  - Safe Windows ComSpec /d /s /c wrapper for .bat/.cmd.
  - Strict environment allowlist: PATH, ComSpec, SystemRoot, temp dirs, ProgramFiles only. No DB credentials, secrets, or .env passed.
  - Flutter commands enforce --no-pub; auto-install forbidden.
  - Checks .dart_tool/package_config.json and backend/node_modules prerequisites; blocks suite if absent.
  - Incremental results persisted after each step under BA_DOCUMENTS/FULL_APP_TEST_20260914/local/<run-dir>/.
  - Exit code nonzero on ANY failure or blocked status.
`);
}

function parseCliArgs(rawArgs) {
  if (rawArgs.length === 0) {
    return { command: 'run' };
  }
  if (rawArgs.length === 1 && (rawArgs[0] === '--help' || rawArgs[0] === '-h' || rawArgs[0] === 'help')) {
    return { command: 'help' };
  }
  if (rawArgs.length === 1 && rawArgs[0] === '--prepare') {
    return { command: 'prepare' };
  }
  if (rawArgs.length === 1 && rawArgs[0] === 'run') {
    return { command: 'run' };
  }
  if (rawArgs.length === 1 && rawArgs[0] === 'flutter-test') {
    return { command: 'flutter-test' };
  }

  throw new Error(`Unknown or rejected arguments: [${rawArgs.join(', ')}]. Supported: --help, --prepare, run, flutter-test`);
}

async function persistIncrementalResults(runDir, summary) {
  const resultsJsonPath = path.join(runDir, 'results.json');
  await fs.writeFile(resultsJsonPath, JSON.stringify(summary, null, 2), 'utf8');
}

async function runStep(step, runDir) {
  const stdoutPath = path.join(runDir, `${step.id}.stdout.log`);
  const stderrPath = path.join(runDir, `${step.id}.stderr.log`);

  const stdoutHandle = await fs.open(stdoutPath, 'w');
  const stderrHandle = await fs.open(stderrPath, 'w');

  const startTime = new Date().toISOString();
  const startMs = Date.now();

  process.stdout.write(`\n>>> [START] ${step.name}\n`);
  process.stdout.write(`    Command: ${step.command}\n`);
  process.stdout.write(`    Cwd:     ${step.cwd}\n`);

  return new Promise((resolve) => {
    let child;
    try {
      child = spawn(step.executable, step.args, {
        cwd: step.cwd,
        env: step.env,
        shell: false,
        windowsHide: true,
        stdio: ['ignore', stdoutHandle.fd, stderrHandle.fd],
      });
    } catch (err) {
      const durationMs = Date.now() - startMs;
      stdoutHandle.close().catch(() => {});
      stderrHandle.close().catch(() => {});
      process.stdout.write(`    [ERROR] Spawn failed: ${err.message}\n`);
      return resolve({
        id: step.id,
        name: step.name,
        command: step.command,
        cwd: step.cwd,
        startTime,
        endTime: new Date().toISOString(),
        durationMs,
        exitCode: null,
        signal: null,
        status: 'FAIL',
        error: err.message,
        stdoutFile: path.basename(stdoutPath),
        stderrFile: path.basename(stderrPath),
      });
    }

    child.on('error', (err) => {
      const durationMs = Date.now() - startMs;
      stdoutHandle.close().catch(() => {});
      stderrHandle.close().catch(() => {});
      process.stdout.write(`    [ERROR] Process error: ${err.message}\n`);
      resolve({
        id: step.id,
        name: step.name,
        command: step.command,
        cwd: step.cwd,
        startTime,
        endTime: new Date().toISOString(),
        durationMs,
        exitCode: null,
        signal: null,
        status: 'FAIL',
        error: err.message,
        stdoutFile: path.basename(stdoutPath),
        stderrFile: path.basename(stderrPath),
      });
    });

    child.on('close', async (exitCode, signal) => {
      const durationMs = Date.now() - startMs;
      await stdoutHandle.close().catch(() => {});
      await stderrHandle.close().catch(() => {});

      const status = exitCode === 0 ? 'PASS' : 'FAIL';
      process.stdout.write(`    [${status}] Exit: ${exitCode}${signal ? ` Signal: ${signal}` : ''} (${durationMs}ms)\n`);

      resolve({
        id: step.id,
        name: step.name,
        command: step.command,
        cwd: step.cwd,
        startTime,
        endTime: new Date().toISOString(),
        durationMs,
        exitCode,
        signal,
        status,
        stdoutFile: path.basename(stdoutPath),
        stderrFile: path.basename(stderrPath),
      });
    });
  });
}

async function executeVerification() {
  const steps = buildCommandInventory();
  const prereqs = checkPrerequisites();

  await fs.mkdir(LOCAL_LOGS_BASE, { recursive: true });
  const runDir = await fs.mkdtemp(path.join(LOCAL_LOGS_BASE, 'run-'));

  process.stdout.write(`========================================================\n`);
  process.stdout.write(`Local Full Verification Run: ${path.basename(runDir)}\n`);
  process.stdout.write(`Logs directory: ${runDir}\n`);
  process.stdout.write(`Total verification suites: ${steps.length}\n`);
  process.stdout.write(`========================================================\n`);

  const results = [];
  const stepStatusMap = new Map();

  const updateSummary = async () => {
    const summary = {
      runId: path.basename(runDir),
      executedAt: new Date().toISOString(),
      projectRoot: PROJECT_ROOT,
      totalSuites: steps.length,
      passed: results.filter((r) => r.status === 'PASS').length,
      failed: results.filter((r) => r.status === 'FAIL').length,
      blocked: results.filter((r) => r.status === 'BLOCKED').length,
      verdict: results.length === steps.length && results.every((r) => r.status === 'PASS') ? 'PASS' : 'FAIL',
      steps: results,
    };
    await persistIncrementalResults(runDir, summary);
    return summary;
  };

  for (const step of steps) {
    // Check prerequisite packages first
    if (step.prereq && !prereqs[step.prereq]) {
      process.stdout.write(`\n>>> [BLOCKED] ${step.name}\n`);
      process.stdout.write(`    Reason: Required prerequisite '${step.prereqDesc}' missing. Auto-install is disabled.\n`);
      const blockedPrereq = {
        id: step.id,
        name: step.name,
        command: step.command,
        cwd: step.cwd,
        startTime: new Date().toISOString(),
        endTime: new Date().toISOString(),
        durationMs: 0,
        exitCode: null,
        signal: null,
        status: 'BLOCKED',
        reason: `Missing prerequisite: ${step.prereqDesc}`,
        stdoutFile: null,
        stderrFile: null,
      };
      results.push(blockedPrereq);
      stepStatusMap.set(step.id, 'BLOCKED');
      await updateSummary();
      continue;
    }

    // Check predecessor dependency
    if (step.dependsOn && stepStatusMap.get(step.dependsOn) !== 'PASS') {
      process.stdout.write(`\n>>> [BLOCKED] ${step.name}\n`);
      process.stdout.write(`    Reason: Required predecessor '${step.dependsOn}' did not PASS (Status: ${stepStatusMap.get(step.dependsOn) || 'UNKNOWN'})\n`);

      const blockedResult = {
        id: step.id,
        name: step.name,
        command: step.command,
        cwd: step.cwd,
        startTime: new Date().toISOString(),
        endTime: new Date().toISOString(),
        durationMs: 0,
        exitCode: null,
        signal: null,
        status: 'BLOCKED',
        reason: `Predecessor '${step.dependsOn}' did not PASS`,
        stdoutFile: null,
        stderrFile: null,
      };
      results.push(blockedResult);
      stepStatusMap.set(step.id, 'BLOCKED');
      await updateSummary();
      continue;
    }

    const stepResult = await runStep(step, runDir);
    results.push(stepResult);
    stepStatusMap.set(step.id, stepResult.status);
    await updateSummary();
  }

  const finalSummary = await updateSummary();

  process.stdout.write(`\n========================================================\n`);
  process.stdout.write(`Verification Run Complete: ${finalSummary.verdict}\n`);
  process.stdout.write(`Passed: ${finalSummary.passed}, Failed: ${finalSummary.failed}, Blocked: ${finalSummary.blocked}\n`);
  process.stdout.write(`Summary saved to: ${path.join(runDir, 'results.json')}\n`);
  process.stdout.write(`========================================================\n`);

  if (finalSummary.verdict !== 'PASS') {
    process.exitCode = 1;
  }
}

async function executeFlutterTestOnly() {
  const steps = buildCommandInventory();
  const step = steps.find((s) => s.id === '03_flutter_test');
  if (!step) {
    throw new Error('Fixed step 03_flutter_test not found in command inventory.');
  }

  const prereqs = checkPrerequisites();

  await fs.mkdir(LOCAL_LOGS_BASE, { recursive: true });
  const runDir = await fs.mkdtemp(path.join(LOCAL_LOGS_BASE, 'run-'));

  process.stdout.write(`========================================================\n`);
  process.stdout.write(`Targeted Flutter Test Run: ${path.basename(runDir)}\n`);
  process.stdout.write(`Logs directory: ${runDir}\n`);
  process.stdout.write(`Executing exclusively: ${step.name} (${step.id})\n`);
  process.stdout.write(`========================================================\n`);

  if (step.prereq && !prereqs[step.prereq]) {
    process.stdout.write(`\n>>> [BLOCKED] ${step.name}\n`);
    process.stdout.write(`    Reason: Required prerequisite '${step.prereqDesc}' missing. Auto-install is disabled.\n`);
    const blockedPrereq = {
      id: step.id,
      name: step.name,
      command: step.command,
      cwd: step.cwd,
      startTime: new Date().toISOString(),
      endTime: new Date().toISOString(),
      durationMs: 0,
      exitCode: null,
      signal: null,
      status: 'BLOCKED',
      reason: `Missing prerequisite: ${step.prereqDesc}`,
      stdoutFile: null,
      stderrFile: null,
    };
    const summary = {
      runId: path.basename(runDir),
      mode: 'flutter-test',
      executedAt: new Date().toISOString(),
      projectRoot: PROJECT_ROOT,
      totalSuites: 1,
      passed: 0,
      failed: 0,
      blocked: 1,
      verdict: 'BLOCKED',
      steps: [blockedPrereq],
    };
    await persistIncrementalResults(runDir, summary);
    process.exitCode = 1;
    return;
  }

  const stepResult = await runStep(step, runDir);
  const summary = {
    runId: path.basename(runDir),
    mode: 'flutter-test',
    executedAt: new Date().toISOString(),
    projectRoot: PROJECT_ROOT,
    totalSuites: 1,
    passed: stepResult.status === 'PASS' ? 1 : 0,
    failed: stepResult.status === 'FAIL' ? 1 : 0,
    blocked: stepResult.status === 'BLOCKED' ? 1 : 0,
    verdict: stepResult.status,
    steps: [stepResult],
  };

  await persistIncrementalResults(runDir, summary);

  process.stdout.write(`\n========================================================\n`);
  process.stdout.write(`Targeted Verification Complete: ${summary.verdict}\n`);
  process.stdout.write(`Status: ${stepResult.status}, Exit: ${stepResult.exitCode}\n`);
  process.stdout.write(`Summary saved to: ${path.join(runDir, 'results.json')}\n`);
  process.stdout.write(`========================================================\n`);

  if (summary.verdict !== 'PASS') {
    process.exitCode = 1;
  }
}

async function prepareInventory() {
  const steps = buildCommandInventory();
  const prereqs = checkPrerequisites();

  process.stdout.write(`=== Full Verification Command Inventory (Read-Only Validation) ===\n`);
  process.stdout.write(`Project Root:      ${PROJECT_ROOT}\n`);
  process.stdout.write(`ComSpec:           ${COMSPEC}\n`);
  process.stdout.write(`Isolation Preload: ${ISOLATION_PRELOAD}\n`);
  process.stdout.write(`Flutter Prereq:    ${prereqs.hasFlutterDeps ? 'FOUND (.dart_tool/package_config.json)' : 'MISSING'}\n`);
  process.stdout.write(`Backend Prereq:    ${prereqs.hasBackendDeps ? 'FOUND (backend/node_modules)' : 'MISSING'}\n`);
  process.stdout.write(`Total Suites:      ${steps.length}\n\n`);

  steps.forEach((step, idx) => {
    process.stdout.write(`Suite [${idx + 1}/${steps.length}]: ${step.name}\n`);
    process.stdout.write(`  ID:          ${step.id}\n`);
    process.stdout.write(`  Command:     ${step.command}\n`);
    process.stdout.write(`  Executable:  ${step.executable}\n`);
    process.stdout.write(`  Cwd:         ${step.cwd}\n`);
    process.stdout.write(`  Independent: ${step.independent}\n`);
    if (step.dependsOn) {
      process.stdout.write(`  DependsOn:   ${step.dependsOn}\n`);
    }
    process.stdout.write(`\n`);
  });

  process.stdout.write(`Command inventory validation SUCCESS. Ready for execution upon permission.\n`);
}

async function main() {
  const parsed = parseCliArgs(process.argv.slice(2));

  if (parsed.command === 'help') {
    printHelp();
    process.exit(0);
  }

  if (parsed.command === 'prepare') {
    await prepareInventory();
    process.exit(0);
  }

  if (parsed.command === 'run') {
    await executeVerification();
  }

  if (parsed.command === 'flutter-test') {
    await executeFlutterTestOnly();
  }
}

main().catch((err) => {
  process.stderr.write(`FATAL: ${err.message}\n`);
  process.exitCode = 1;
});
