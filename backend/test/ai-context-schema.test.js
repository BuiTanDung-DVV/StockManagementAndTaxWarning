const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '../src/services/ai.service.ts'), 'utf8');

test('AI category query uses the category relation scoped to the shop', () => {
  assert.match(source, /JOIN categories c ON c.id = p.category_id AND c.shop_id = p.shop_id/);
  assert.match(source, /SELECT DISTINCT c.name AS category/);
  assert.doesNotMatch(source, /SELECT DISTINCT category\s+FROM products/);
});

test('AI reuses net sales and top-product accounting instead of a nonexistent column', () => {
  assert.match(source, /sales.netSalesRevenue/);
  assert.match(source, /this.salesService.getTopProducts\(/);
  assert.doesNotMatch(source, /item.line_total/);
});
