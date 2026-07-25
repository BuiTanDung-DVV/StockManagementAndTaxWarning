const test = require('node:test');
const assert = require('node:assert/strict');

const {
  calculateNetAmount,
  normalizeSalesStatusFilter,
} = require('../dist/sales/sales-metric.utils');

test('completed filter includes legacy and current completed statuses', () => {
  assert.deepEqual(normalizeSalesStatusFilter('completed'), [
    'COMPLETED',
    'DELIVERED',
  ]);
});

test('status filters are normalized and invalid values are rejected', () => {
  assert.deepEqual(normalizeSalesStatusFilter(' pending '), ['PENDING']);
  assert.equal(normalizeSalesStatusFilter(), undefined);
  assert.throws(
    () => normalizeSalesStatusFilter('UNKNOWN'),
    /Invalid sales order status/,
  );
});

test('net amount uses the same income minus expense definition', () => {
  assert.equal(calculateNetAmount(500_000, 125_000), 375_000);
});
