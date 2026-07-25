const test = require('node:test');
const assert = require('node:assert/strict');

const {
  CURRENT_TAX_POLICY,
  TaxValidationError,
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
  assert.equal(isValidVietnamTaxCode('0123456789'), true);
  assert.equal(isValidVietnamTaxCode('0123456789-001'), true);
  assert.equal(isValidVietnamTaxCode('0123456789001'), true);
});

test('missing or malformed tax code blocks XML export', () => {
  for (const value of [undefined, '', '123', 'abcdefghij']) {
    assert.throws(() => requireValidTaxCode(value), TaxValidationError);
  }
});

test('tax period accepts valid months and quarters only', () => {
  assert.doesNotThrow(() => validateTaxPeriod('12', '2026'));
  assert.doesNotThrow(() => validateTaxPeriod('Q4', '2026'));
  assert.throws(() => validateTaxPeriod('13', '2026'), TaxValidationError);
  assert.throws(() => validateTaxPeriod('Q5', '2026'), TaxValidationError);
  assert.throws(() => validateTaxPeriod('01', '26'), TaxValidationError);
  assert.throws(() => validateTaxPeriod('01', '2025'), TaxValidationError);
});
