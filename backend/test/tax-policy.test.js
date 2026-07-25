const test = require('node:test');
const assert = require('node:assert/strict');

const {
  CURRENT_TAX_POLICY,
  TaxValidationError,
  calculateOutstandingTax,
  isValidVietnamTaxCode,
  normalizeNonNegative,
  requireValidTaxCode,
  validateTaxPeriod,
} = require('../dist/tax/tax-policy');

test('current policy uses the official 2026 one-billion threshold', () => {
  assert.equal(CURRENT_TAX_POLICY.fiscalYear, 2026);
  assert.equal(CURRENT_TAX_POLICY.taxExemptionThreshold, 1_000_000_000);
  assert.equal(CURRENT_TAX_POLICY.eInvoiceThreshold, 1_000_000_000);
});

test('negative and invalid monetary values never create negative tax', () => {
  assert.equal(normalizeNonNegative(-1), 0);
  assert.equal(normalizeNonNegative(Number.NaN), 0);
  assert.equal(normalizeNonNegative(125_000), 125_000);
});

test('tax code accepts head-office and dependent-unit formats', () => {
  assert.equal(isValidVietnamTaxCode('0100109106'), true);
  assert.equal(isValidVietnamTaxCode('0100109106-001'), true);
  assert.equal(isValidVietnamTaxCode('0100109106001'), true);
});

test('legacy placeholder tax code is never accepted for XML export', () => {
  assert.equal(isValidVietnamTaxCode('0123456789'), false);
  assert.equal(isValidVietnamTaxCode('0123456789-001'), false);
  assert.equal(isValidVietnamTaxCode('0123456789001'), false);
  assert.throws(() => requireValidTaxCode('0123456789'), TaxValidationError);
});

test('missing or malformed tax code blocks XML export', () => {
  for (const value of [undefined, '', '123', 'abcdefghij']) {
    assert.throws(() => requireValidTaxCode(value), TaxValidationError);
  }
});

test('outstanding tax is never negative and preserves overpayment separately', () => {
  assert.deepEqual(calculateOutstandingTax(1_500_000, 500_000), {
    owed: 1_000_000,
    overpaid: 0,
  });
  assert.deepEqual(calculateOutstandingTax(500_000, 1_500_000), {
    owed: 0,
    overpaid: 1_000_000,
  });
  assert.deepEqual(calculateOutstandingTax(-1, Number.NaN), {
    owed: 0,
    overpaid: 0,
  });
});

test('tax period accepts valid months and quarters only', () => {
  assert.doesNotThrow(() => validateTaxPeriod('12', '2026'));
  assert.doesNotThrow(() => validateTaxPeriod('Q4', '2026'));
  assert.throws(() => validateTaxPeriod('13', '2026'), TaxValidationError);
  assert.throws(() => validateTaxPeriod('Q5', '2026'), TaxValidationError);
  assert.throws(() => validateTaxPeriod('01', '26'), TaxValidationError);
  assert.throws(() => validateTaxPeriod('01', '2025'), TaxValidationError);
});
