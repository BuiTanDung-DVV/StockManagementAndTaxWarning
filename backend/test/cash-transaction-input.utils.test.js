const test = require('node:test');
const assert = require('node:assert/strict');

const {
  cashLedgerAccountCode,
  normalizeCashPaymentMethod,
  normalizeCashTransactionInput,
} = require('../dist/finance/cash-transaction-input.utils.js');

test('cash uses account 111 and digital payments use account 112', () => {
  assert.equal(cashLedgerAccountCode('CASH'), '111');
  assert.equal(cashLedgerAccountCode('TRANSFER'), '112');
  assert.equal(cashLedgerAccountCode('QR'), '112');
});
test('cash transaction input is normalized and server controlled', () => {
  const result = normalizeCashTransactionInput({
    type: 'income',
    amount: '125000',
    category: ' other ',
    paymentMethod: 'transfer',
    description: 'Thu khác',
    transactionDate: '2026-08-09',
  });
  assert.equal(result.type, 'INCOME');
  assert.equal(result.amount, 125000);
  assert.equal(result.category, 'OTHER');
  assert.equal(result.paymentMethod, 'TRANSFER');
  assert.equal(result.notes, 'Thu khác');
});

test('cash transaction rejects invalid accounting values', () => {
  assert.throws(
    () => normalizeCashTransactionInput({ type: 'OTHER', amount: 1, category: 'OTHER' }),
    /Type must be INCOME or EXPENSE/,
  );
  assert.throws(
    () => normalizeCashTransactionInput({ type: 'INCOME', amount: 0, category: 'OTHER' }),
    /Amount must be greater than 0/,
  );
  assert.throws(() => normalizeCashPaymentMethod('BITCOIN'), /Unsupported payment method/);
});
