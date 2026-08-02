const test = require('node:test');
const assert = require('node:assert/strict');

const {
  allowedUnitPrices,
  assertAllowedUnitPrice,
} = require('../dist/sales/sales-pricing.utils.js');

const product = {
  sellingPrice: 100_000,
  wholesalePrice: 85_000,
  wholesaleMinQty: 10,
  promoPrice: 90_000,
  promoStart: '2026-08-01',
  promoEnd: '2026-08-31',
};

test('accepts configured retail price and rejects arbitrary client price', () => {
  assert.equal(
    assertAllowedUnitPrice(100_000, product, 1, new Date('2026-08-15T00:00:00Z')),
    100_000,
  );
  assert.throws(
    () => assertAllowedUnitPrice(1, product, 1, new Date('2026-08-15T00:00:00Z')),
    /does not match product pricing/,
  );
});
test('only accepts wholesale price from the configured minimum quantity', () => {
  assert.throws(
    () => assertAllowedUnitPrice(85_000, product, 9),
    /does not match product pricing/,
  );
  assert.equal(assertAllowedUnitPrice(85_000, product, 10), 85_000);
});

test('only exposes promotional price during its Vietnam effective dates', () => {
  assert.deepEqual(
    allowedUnitPrices(product, 1, new Date('2026-07-31T16:59:59Z')),
    [100_000],
  );
  assert.deepEqual(
    allowedUnitPrices(product, 1, new Date('2026-07-31T17:00:00Z')),
    [100_000, 90_000],
  );
  assert.deepEqual(
    allowedUnitPrices(product, 1, new Date('2026-08-31T16:59:59Z')),
    [100_000, 90_000],
  );
});

test('rejects missing, negative and non-finite prices', () => {
  assert.throws(() => assertAllowedUnitPrice(undefined, product, 1));
  assert.throws(() => assertAllowedUnitPrice(-1, product, 1));
  assert.throws(() => assertAllowedUnitPrice(Number.NaN, product, 1));
});
