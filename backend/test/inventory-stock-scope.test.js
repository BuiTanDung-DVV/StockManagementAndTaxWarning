const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const service = fs.readFileSync(path.join(__dirname, '../src/services/inventory.service.ts'), 'utf8');
const controller = fs.readFileSync(path.join(__dirname, '../src/controllers/inventory.controller.ts'), 'utf8');
const provider = fs.readFileSync(path.join(__dirname, '../../lib/features/inventory/providers/inventory_provider.dart'), 'utf8');

test('inventory stock API applies the selected warehouse to the database query', () => {
  assert.match(service, /async getStock\(shopId: number \| number\[\], page = 1, limit = 20, warehouseId\?: number\)/);
  assert.match(service, /shopId: scopedShopId, warehouseId/);
  assert.match(controller, /req\.query\.warehouseId/);
  assert.match(controller, /getStock\(getShopId\(req\), page, limit, warehouseId\)/);
  assert.match(service, /latestMovementDate: normalizeDatabaseBusinessDate/);
  assert.match(service, /movement\.warehouse_id = :warehouseId/);
});

test('inventory provider requests enough database rows for transactional selectors', () => {
  assert.match(provider, /getCurrentStock\(\{int\? warehouseId, int limit = 500\}\)/);
  assert.match(provider, /'page': '1', 'limit': '\$limit'/);
});
