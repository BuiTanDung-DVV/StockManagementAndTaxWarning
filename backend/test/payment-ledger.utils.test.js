const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

const {
  groupSettledPaymentsByMethod,
  paymentLedgerAccountCode,
} = require(path.join(
  __dirname,
  '..',
  'dist',
  'sales',
  'payment-ledger.utils.js',
));

test('cash posts to 111 while transfer, QR and cards post to 112', () => {
  assert.equal(paymentLedgerAccountCode('CASH'), '111');
  assert.equal(paymentLedgerAccountCode('TRANSFER'), '112');
  assert.equal(paymentLedgerAccountCode('BANK_TRANSFER'), '112');
  assert.equal(paymentLedgerAccountCode('QR'), '112');
  assert.equal(paymentLedgerAccountCode('CARD'), '112');
});

test('refund grouping preserves each actual payment channel', () => {
  assert.deepEqual(
    groupSettledPaymentsByMethod([
      { method: 'CASH', amount: 100000 },
      { method: 'TRANSFER', amount: 250000 },
      { method: 'cash', amount: 50000 },
    ]),
    [
      { method: 'CASH', amount: 150000 },
      { method: 'TRANSFER', amount: 250000 },
    ],
  );
});

test('settled payment rejects debt labels and invalid amounts', () => {
  assert.throws(() => paymentLedgerAccountCode('DEBT'), /Unsupported/);
  assert.throws(
    () => groupSettledPaymentsByMethod([{ method: 'CASH', amount: -1 }]),
    /Invalid settled payment amount/,
  );
});
