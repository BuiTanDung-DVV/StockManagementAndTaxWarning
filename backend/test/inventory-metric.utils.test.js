const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

test('inventory category summary reports cost value and comparable SKU count', () => {
  const source = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'services', 'inventory.service.ts'),
    'utf8',
  );

  assert.match(source, /SUM\(s\.quantity \* p\.cost_price\)/);
  assert.match(source, /COUNT\(DISTINCT p\.id\) as sku_count/);
  assert.match(source, /WHERE \$\{shopCondition\} AND s\.quantity > 0/);
  assert.match(source, /skuCount: Number\(r\.sku_count\)/);
});

test('stock movement report keeps product units and uses comparable SKU cards', () => {
  const source = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'services', 'inventory.service.ts'),
    'utf8',
  );

  assert.match(source, /p\.unit as unit/);
  assert.match(source, /unit: row\.unit/);
  assert.match(source, /openingSkuCount/);
  assert.match(source, /importedSkuCount/);
  assert.match(source, /exportedSkuCount/);
  assert.match(source, /closingSkuCount/);
});

test('slow-moving inventory is shop-scoped and exposes usable product fields', () => {
  const source = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'services', 'inventory.service.ts'),
    'utf8',
  );

  assert.match(source, /s\.shop_id = p\.shop_id/);
  assert.match(source, /sales_order_items/);
  assert.match(source, /sold_order\.shop_id = :shopId/);
  assert.match(source, /last_order\.shop_id = :shopId/);
  assert.match(source, /sold_order\.status != 'CANCELLED'/);
  assert.match(source, /productName: row\.name/);
  assert.match(source, /currentQuantity: Number\(row\.currentStock \|\| 0\)/);
  assert.match(source, /daysSinceLastSale/);
});
