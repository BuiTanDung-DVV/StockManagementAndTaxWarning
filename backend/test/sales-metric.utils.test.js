const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

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

test('sales list query uses TypeORM entity property paths', () => {
  const source = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'services', 'sales.service.ts'),
    'utf8',
  );

  assert.match(source, /\.where\('o\.shopId = :shopId'/);
  assert.match(source, /\.orderBy\('o\.createdAt', 'DESC'\)/);
  assert.match(source, /LOWER\(o\.orderCode\)/);
});

test('top products report exposes quantity and returns up to ten products', () => {
  const source = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'services', 'sales.service.ts'),
    'utf8',
  );

  assert.match(source, /SUM\(oi\.quantity\) as quantity/);
  assert.match(source, /LIMIT 10/);
  assert.match(source, /quantity: Number\(p\.quantity\)/);
});
