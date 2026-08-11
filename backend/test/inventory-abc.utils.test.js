const assert = require('node:assert/strict');
const test = require('node:test');
const path = require('node:path');

const modulePath = path.join(
  __dirname,
  '..',
  'dist',
  'inventory',
  'inventory-abc.utils.js',
);
const { classifyInventoryAbc } = require(modulePath);

const row = (id, revenue, stockValue = 0) => ({
  id,
  sku: `SKU-${id}`,
  name: `Sản phẩm ${id}`,
  unit: 'Cái',
  category: 'Thử nghiệm',
  revenue,
  quantitySold: revenue / 10,
  currentStock: id,
  stockValue,
});

test('classifies products by cumulative revenue share', () => {
  const result = classifyInventoryAbc([
    row(1, 70, 10),
    row(2, 20, 20),
    row(3, 7, 30),
    row(4, 3, 40),
  ]);

  assert.deepEqual(result.items.map((item) => item.grade), ['A', 'B', 'C', 'C']);
  assert.equal(result.totalRevenue, 100);
  assert.equal(result.totalStockValue, 100);
  assert.equal(result.grades[0].revenueShare, 0.7);
  assert.equal(result.grades[2].skuCount, 2);
});

test('normalizes invalid and negative measures without producing NaN', () => {
  const result = classifyInventoryAbc([
    row(2, Number.NaN, -20),
    row(1, -100, 50),
  ]);

  assert.equal(result.totalRevenue, 0);
  assert.equal(result.totalStockValue, 50);
  assert.ok(result.items.every((item) => item.grade === 'C'));
  assert.ok(result.items.every((item) => Number.isFinite(item.cumulativeShare)));
});
