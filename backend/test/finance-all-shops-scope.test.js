const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const serviceSource = fs.readFileSync(
  path.join(__dirname, '..', 'src', 'services', 'finance.service.ts'),
  'utf8',
);
const controllerSource = fs.readFileSync(
  path.join(__dirname, '..', 'src', 'controllers', 'finance.controller.ts'),
  'utf8',
);

test('finance transaction and expense APIs use the selected multi-shop scope', () => {
  assert.match(
    controllerSource,
    /getCashTransactions\(\s*getShopId\(req\)/,
  );
  assert.match(
    controllerSource,
    /getExpensesByCategory\(getShopId\(req\)/,
  );
  assert.match(
    serviceSource,
    /getCashTransactions\(\s*shopId: number \| number\[\]/,
  );
  assert.match(
    controllerSource,
    /getCashTransaction\(getShopId\(req\)/,
  );
  assert.match(
    serviceSource,
    /getCashTransaction\(shopId: number \| number\[\], id: number\)/,
  );
  assert.match(
    serviceSource,
    /getExpensesByCategory\(shopId: number \| number\[\]/,
  );
  assert.match(serviceSource, /t\.shop_id IN \(:\.\.\.shopIds\)/);
  assert.match(
    serviceSource,
    /shopId: Array\.isArray\(shopId\) \? In\(shopId\) : shopId/,
  );
});

test('cash-flow response identifies an all-shops aggregate explicitly', () => {
  assert.match(
    serviceSource,
    /scope: Array\.isArray\(shopId\) \? 'ALL_SHOPS' : 'SHOP'/,
  );
});
