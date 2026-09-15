/**
 * scripts/test-isolation.cjs
 * 
 * Process-level test isolation preload script for Node.js test runner (`node --require <this_file> --test ...`).
 *
 * Scope & Guarantees:
 * 1. Overrides `dotenv.config()` and `dotenv.configDotenv()` to no-ops returning `{ parsed: {} }`.
 *    Prevents reading `.env` or leaking production secrets during backend test execution.
 * 2. Blocks outbound network connections via `net.Socket.prototype.connect`, `tls.connect`,
 *    `http.request`, `http.get`, `https.request`, `https.get`, and default `global.fetch`.
 *    Unit tests that explicitly mock `global.fetch` (e.g. legal-grounding.service.test.js) can still do so.
 * 3. Injects non-secret dummy authentication/encryption keys (>= 32 bytes) for tests requiring valid tokens.
 *
 * Limitations:
 * - This provides process-level runtime isolation within Node.js, NOT an OS-level container or hypervisor sandbox.
 */

const Module = require('node:module');
const net = require('node:net');
const tls = require('node:tls');
const http = require('node:http');
const https = require('node:https');

// --- 1. Invalidate & Override Dotenv ---
function patchDotenv(dotenvModule) {
  if (!dotenvModule) return;
  const noop = () => ({ parsed: {} });
  dotenvModule.config = noop;
  dotenvModule.configDotenv = noop;
  if (dotenvModule.default) {
    dotenvModule.default.config = noop;
    dotenvModule.default.configDotenv = noop;
  }
}

try {
  const resolvedDotenv = require('dotenv');
  patchDotenv(resolvedDotenv);
} catch {
  // Will be caught by Module hook if loaded later
}

const originalRequire = Module.prototype.require;
Module.prototype.require = function (id) {
  const loaded = originalRequire.apply(this, arguments);
  if (id === 'dotenv' || id.endsWith('/dotenv') || id.endsWith('\\dotenv')) {
    patchDotenv(loaded);
  }
  return loaded;
};

// --- 2. Block Live Outbound Network Connections ---
const originalSocketConnect = net.Socket.prototype.connect;
net.Socket.prototype.connect = function () {
  const err = new Error('[TEST ISOLATION] Blocked outbound TCP socket connection during unit test execution.');
  err.code = 'ENETWORK_ISOLATED';
  throw err;
};

const originalTlsConnect = tls.connect;
tls.connect = function () {
  const err = new Error('[TEST ISOLATION] Blocked outbound TLS connection during unit test execution.');
  err.code = 'ENETWORK_ISOLATED';
  throw err;
};

http.request = function () {
  const err = new Error('[TEST ISOLATION] Blocked outbound HTTP request during unit test execution.');
  err.code = 'ENETWORK_ISOLATED';
  throw err;
};
http.get = function () {
  const err = new Error('[TEST ISOLATION] Blocked outbound HTTP GET request during unit test execution.');
  err.code = 'ENETWORK_ISOLATED';
  throw err;
};

https.request = function () {
  const err = new Error('[TEST ISOLATION] Blocked outbound HTTPS request during unit test execution.');
  err.code = 'ENETWORK_ISOLATED';
  throw err;
};
https.get = function () {
  const err = new Error('[TEST ISOLATION] Blocked outbound HTTPS GET request during unit test execution.');
  err.code = 'ENETWORK_ISOLATED';
  throw err;
};

if (typeof global.fetch === 'function') {
  global.fetch = async function () {
    const err = new Error('[TEST ISOLATION] Blocked outbound fetch call during unit test execution.');
    err.code = 'ENETWORK_ISOLATED';
    throw err;
  };
}

// --- 3. Inject Safe Dummy Non-Secret Environment Variables ---
process.env.NODE_ENV = 'test';
process.env.ACCESS_TOKEN_SECRET = 'dummy-test-access-token-secret-at-least-32-bytes-long';
process.env.REFRESH_TOKEN_SECRET = 'dummy-test-refresh-token-secret-at-least-32-bytes-long';
process.env.OTP_SECRET = 'dummy-test-otp-secret-at-least-32-bytes-long';
process.env.JWT_SECRET = 'dummy-test-access-token-secret-at-least-32-bytes-long';
process.env.CLOUDINARY_CLOUD_NAME = process.env.CLOUDINARY_CLOUD_NAME || 'demo';

// Wipe any accidental DB connection variables in process
delete process.env.DATABASE_URL;
delete process.env.DB_PASSWORD;
delete process.env.SUPABASE_KEY;
delete process.env.SUPABASE_URL;
