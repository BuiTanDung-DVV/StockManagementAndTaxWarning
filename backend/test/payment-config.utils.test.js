const test = require('node:test');
const assert = require('node:assert/strict');

const {
  DEFAULT_PAYMENT_BANK_OPTIONS,
  parsePaymentBankOptions,
} = require('../dist/system/payment-config.utils.js');

test('default payment banks provide a usable VietQR fallback', () => {
  assert.ok(DEFAULT_PAYMENT_BANK_OPTIONS.length >= 20);
  assert.ok(DEFAULT_PAYMENT_BANK_OPTIONS.some((bank) => bank.id === 'VCB'));
  assert.equal(
    new Set(DEFAULT_PAYMENT_BANK_OPTIONS.map((bank) => bank.id)).size,
    DEFAULT_PAYMENT_BANK_OPTIONS.length,
  );
});

test('payment bank options are parsed from database JSON', () => {
  assert.deepEqual(
    parsePaymentBankOptions('[{"id":"vcb","name":"Vietcombank"}]'),
    [{ id: 'VCB', name: 'Vietcombank' }],
  );
});

test('payment bank database configuration rejects invalid or duplicate rows', () => {
  assert.throws(() => parsePaymentBankOptions('not-json'), /không phải JSON/);
  assert.throws(() => parsePaymentBankOptions('[]'), /đang rỗng/);
  assert.throws(
    () => parsePaymentBankOptions('[{"id":"VCB","name":"A"},{"id":"vcb","name":"B"}]'),
    /trùng mã VCB/,
  );
});
