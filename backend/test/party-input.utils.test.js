const test = require('node:test');
const assert = require('node:assert/strict');

const {
  PartyInputError,
  normalizeCustomerInput,
  normalizeSupplierInput,
} = require('../dist/party/party-input.utils');

test('customer input keeps business fields and normalizes legacy note', () => {
  assert.deepEqual(normalizeCustomerInput({
    name: '  Nguyễn Văn An ',
    email: 'an@example.vn',
    creditLimit: '5000000',
    note: 'Khách công trình',
    tags: ['VIP', 'VIP'],
  }, true), {
    name: 'Nguyễn Văn An',
    email: 'an@example.vn',
    creditLimit: 5000000,
    notes: 'Khách công trình',
    tags: ['VIP'],
  });
});

test('customer input rejects scope, balance and lifecycle fields', () => {
  for (const input of [
    { name: 'Khách A', shopId: 99 },
    { name: 'Khách A', balance: 1000000 },
    { name: 'Khách A', code: 'CUS-HACK' },
    { name: 'Khách A', isActive: false },
  ]) {
    assert.throws(() => normalizeCustomerInput(input, true), PartyInputError);
  }
});

test('supplier input keeps supported payment information', () => {
  assert.deepEqual(normalizeSupplierInput({
    name: '  Công ty An Phát ',
    contactName: 'Chị Lan',
    paymentTermDays: '30',
    bankAccount: '0123456789',
  }, true), {
    name: 'Công ty An Phát',
    contactPerson: 'Chị Lan',
    paymentTermDays: 30,
    bankAccount: '0123456789',
  });
});

test('party input validates email, number ranges and unknown fields', () => {
  assert.throws(() => normalizeCustomerInput({ email: 'invalid' }), PartyInputError);
  assert.throws(() => normalizeCustomerInput({ creditLimit: -1 }), PartyInputError);
  assert.throws(() => normalizeSupplierInput({ paymentTermDays: 1.5 }), PartyInputError);
  assert.throws(() => normalizeSupplierInput({ balance: 1 }), PartyInputError);
});
