const test = require('node:test');
const assert = require('node:assert/strict');

const {
  parsePaymentBankOptions,
} = require('../dist/system/payment-config.utils.js');

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
