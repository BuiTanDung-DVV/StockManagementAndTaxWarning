const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const routesSource = fs.readFileSync(
  path.join(__dirname, '..', 'src', 'routes', 'sales.routes.ts'),
  'utf8',
);
const controllerSource = fs.readFileSync(
  path.join(__dirname, '..', 'src', 'controllers', 'sales.controller.ts'),
  'utf8',
);
const serviceSource = fs.readFileSync(
  path.join(__dirname, '..', 'src', 'services', 'sales.service.ts'),
  'utf8',
);

test('sales order list accepts the authorized all-shops read scope', () => {
  assert.match(
    routesSource,
    /sales-orders'.*requirePermission\('sales', 'view', \{ allowAllShops: true \}\)/,
  );
  assert.match(
    controllerSource,
    /isAllShops \? \(req as any\)\.shopIds : \(req as any\)\.shopId/,
  );
  assert.match(
    serviceSource,
    /findAll\([\s\S]*?shopId: number \| number\[\]/,
  );
  assert.match(serviceSource, /o\.shopId IN \(:\.\.\.shopIds\)/);
});

test('sales order list applies a complete Vietnam business-date period in PostgreSQL', () => {
  assert.match(controllerSource, /req\.query\.from as string/);
  assert.match(controllerSource, /req\.query\.to as string/);
  assert.match(serviceSource, /Kỳ danh sách cần đủ ngày bắt đầu và kết thúc/);
  assert.match(serviceSource, /resolveCurrentMonthExpensePeriod\(from, to\)/);
  assert.match(
    serviceSource,
    /o\.orderDate >= CAST\(:fromKey AS date\) AND o\.orderDate < CAST\(:toKey AS date\) \+ INTERVAL '1 day'/,
  );
});

test('sales order list rejects an empty aggregate scope', () => {
  assert.match(serviceSource, /if \(shopId\.length === 0\)/);
  assert.match(serviceSource, /Phạm vi cửa hàng không hợp lệ/);
});
