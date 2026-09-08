const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const databaseDir = path.join(__dirname, '..', 'database');

test('payment QR migration is additive, nullable and reversible', () => {
  const up = fs.readFileSync(
    path.join(databaseDir, '20260907_add_payment_qr_details.sql'),
    'utf8',
  );
  const down = fs.readFileSync(
    path.join(databaseDir, '20260907_add_payment_qr_details.rollback.sql'),
    'utf8',
  );

  assert.match(up, /ADD COLUMN IF NOT EXISTS qr_payment_payload TEXT/i);
  assert.match(up, /ADD COLUMN IF NOT EXISTS qr_payment_details JSONB/i);
  assert.doesNotMatch(up, /NOT NULL/i);
  assert.match(down, /DROP COLUMN IF EXISTS qr_payment_payload/i);
  assert.match(down, /DROP COLUMN IF EXISTS qr_payment_details/i);
});

test('payment QR migration runner requires explicit confirmation and checks row count', () => {
  const runner = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'scripts', 'apply-payment-qr-migration.ts'),
    'utf8',
  );
  assert.match(runner, /--confirm=MIGRATE-PAYMENT-QR/);
  assert.match(runner, /before\[0\]\?\.count !== after\[0\]\?\.count/);
  assert.match(runner, /startTransaction\(\)/);
  assert.match(runner, /rollbackTransaction\(\)/);
});
