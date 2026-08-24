const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const service = fs.readFileSync(
  path.join(__dirname, '..', 'src', 'services', 'inventory.service.ts'),
  'utf8',
);

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

test('stock movement report uses Vietnam business-day boundaries', () => {
  assert.match(service, /async getXntReport[\s\S]*resolveCurrentMonthExpensePeriod\(from, to\)/);
  assert.doesNotMatch(service, /const fromDate = from \? new Date\(from\)/);
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
  assert.match(source, /SUM\(s\.quantity\) \* p\.cost_price/);
  assert.match(source, /stockValue: Number\(row\.stockValue \|\| 0\)/);
  assert.match(source, /orderBy\('\"stockValue\"', 'DESC'\)/);
});

test('inventory overview supports authorized all-shop reads and distinct product totals', () => {
  const routeSource = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'routes', 'inventory.routes.ts'),
    'utf8',
  );
  const controllerSource = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'controllers', 'inventory.controller.ts'),
    'utf8',
  );

  assert.match(service, /COUNT\(DISTINCT stock\.product_id\)/);
  assert.match(service, /productTotal/);
  assert.match(controllerSource, /getStock\(getShopId\(req\), page, limit, warehouseId\)/);
  assert.match(controllerSource, /getExpiringProducts\(getShopId\(req\), daysAhead\)/);
  assert.match(controllerSource, /getSlowMovingProducts\(getShopId\(req\), daysUnsold\)/);
  assert.match(controllerSource, /Số ngày chậm luân chuyển không hợp lệ/);
  assert.match(controllerSource, /Bộ lọc kho yêu cầu chọn một cửa hàng cụ thể/);
  assert.match(routeSource, /\/inventory\/stock'[\s\S]*allowAllShops: true/);
});

test('low-stock API aggregates one row per product instead of warehouse rows', () => {
  assert.match(service, /async getLowStock[\s\S]*SUM\(s\.quantity\)/);
  assert.match(service, /GROUP BY[\s\S]*s\.shop_id,[\s\S]*p\.id/);
  assert.match(service, /HAVING COALESCE\(SUM\(s\.quantity\), 0\)/);
  assert.match(service, /COUNT\(DISTINCT s\.warehouse_id\) AS warehouse_count/);
  assert.match(service, /currentQuantity: quantity/);
  assert.match(service, /warehouseCount: Number\(row\.warehouse_count/);
});
