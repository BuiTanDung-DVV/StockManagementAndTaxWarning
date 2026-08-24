const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const service = fs.readFileSync(path.join(__dirname, '../src/services/inventory.service.ts'), 'utf8');
const controller = fs.readFileSync(path.join(__dirname, '../src/controllers/inventory.controller.ts'), 'utf8');
const provider = fs.readFileSync(path.join(__dirname, '../../lib/features/inventory/providers/inventory_provider.dart'), 'utf8');

test('movement history keeps the selected product scope from UI to database', () => {
  assert.match(provider, /params\['productId'\] = '\$productId'/);
  assert.match(controller, /req\.query\.productId/);
  assert.match(controller, /getMovements\(\(req as any\)\.shopId, page, limit, productId\)/);
  assert.match(service, /const where = productId === undefined \? \{ shopId \} : \{ shopId, productId \}/);
});

test('movement history rejects a product outside the active shop', () => {
  assert.match(service, /exists\(\{\s*where: \{ id: productId, shopId \}/);
  assert.match(service, /Validation: Product not found for shop/);
});
