const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const service = fs.readFileSync(
  path.join(__dirname, '..', 'src', 'services', 'sales.service.ts'),
  'utf8',
);
const routes = fs.readFileSync(
  path.join(__dirname, '..', 'src', 'routes', 'sales.routes.ts'),
  'utf8',
);

test('sales summary exposes a return-rate guardrail from net merchandise values', () => {
  assert.match(
    service,
    /returnNetSalesRevenue \/ grossNetSalesRevenue\) \* 100/,
  );
  assert.match(service, /returnRatePct,/);
});

test('top returned products come from accepted database return lines', () => {
  assert.match(routes, /sales-orders\/top-returns/);
  assert.match(service, /getTopReturnedProducts\(/);
  assert.match(service, /JOIN sales_return_items ri ON ri\.return_id = r\.id/);
  assert.match(service, /JOIN products p ON p\.id = ri\.product_id/);
  assert.match(service, /NOT IN \('CANCELLED', 'REJECTED'\)/);
  assert.match(service, /ORDER BY value DESC, quantity DESC, p\.id ASC/);
  assert.match(service, /LIMIT 5/);
});
