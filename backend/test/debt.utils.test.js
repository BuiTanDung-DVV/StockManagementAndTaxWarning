const test = require('node:test');
const assert = require('node:assert/strict');

const {
  applyDebtPayment,
  calculateRemainingDebt,
} = require('../dist/customer/debt.utils');

test('remaining debt is never negative', () => {
  assert.equal(calculateRemainingDebt(1_000_000, 250_000), 750_000);
  assert.equal(calculateRemainingDebt(1_000_000, 1_500_000), 0);
});

test('partial collection keeps receivable open', () => {
  assert.deepEqual(applyDebtPayment(1_000_000, 0, 250_000), {
    paidAmount: 250_000,
    remaining: 750_000,
    status: 'PARTIAL',
  });
});

test('full collection closes receivable', () => {
  assert.deepEqual(applyDebtPayment(1_000_000, 250_000, 750_000), {
    paidAmount: 1_000_000,
    remaining: 0,
    status: 'PAID',
  });
});

test('invalid or excessive collection is rejected', () => {
  assert.throws(() => applyDebtPayment(1_000_000, 0, 0), /greater than 0/);
  assert.throws(
    () => applyDebtPayment(1_000_000, 900_000, 200_000),
    /exceeds remaining receivable balance/,
  );
});
