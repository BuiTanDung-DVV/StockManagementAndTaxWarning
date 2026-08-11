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

test('returned COGS is calculated from returned quantity and sold unit cost', () => {
  const source = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'services', 'sales.service.ts'),
    'utf8',
  );

  assert.match(source, /SUM\(ri\.quantity \* sold\.unit_cost\)/);
  assert.doesNotMatch(source, /SUM\(ro\.total_cogs\)/);
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

test('sales detail loads the same customer relation as the sales list', () => {
  const source = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'services', 'sales.service.ts'),
    'utf8',
  );

  assert.match(
    source,
    /relations: \['customer', 'items', 'items\.product', 'payments'\]/,
  );
});

test('sales creation rejects invalid identity, date and empty orders', () => {
  const source = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'services', 'sales.service.ts'),
    'utf8',
  );

  assert.match(source, /Order date is invalid/);
  assert.match(source, /Customer not found/);
  assert.match(source, /Order must contain at least one item/);
});

test('top products report uses stable ids and subtracts accepted returns', () => {
  const source = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'services', 'sales.service.ts'),
    'utf8',
  );

  assert.match(source, /WITH sold_cost AS/);
  assert.match(source, /\), sold AS/);
  assert.match(source, /buildAllocatedMerchandiseRevenueSql\(/);
  assert.match(source, /JOIN sales_orders returned_order ON returned_order\.id = r\.order_id/);
  assert.match(source, /SUM\(oi\.quantity\) AS gross_quantity/);
  assert.match(source, /SUM\(oi\.quantity \* oi\.cost_price\) AS gross_cogs/);
  assert.match(source, /SUM\(ri\.quantity\) AS return_quantity/);
  assert.match(source, /SUM\(ri\.quantity \* sold_cost\.unit_cost\) AS return_cogs/);
  assert.match(source, /LEFT JOIN returned ON returned\.product_id = sold\.id/);
  assert.match(source, /previous_sold AS/);
  assert.match(source, /previous_returned AS/);
  assert.match(source, /LEFT JOIN previous_net ON previous_net\.id = sold\.id/);
  assert.match(source, /previous_net\.value AS previous_value/);
  assert.match(source, /NOT IN \('CANCELLED', 'REJECTED'\)/);
  assert.match(source, /id: Number\(p\.id\)/);
  assert.match(source, /LIMIT 10/);
  assert.match(source, /quantity: Number\(p\.quantity\)/);
  assert.match(source, /grossProfit: Number\(p\.gross_profit\)/);
  assert.match(source, /previousValue: p\.previous_value == null/);
  assert.match(source, /marginPct: Number\(p\.value\) > 0/);
  assert.match(source, /unit: p\.unit \|\| 'Sản phẩm'/);
});

test('payment method chart is based on recorded payments in the selected period', () => {
  const source = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'services', 'sales.service.ts'),
    'utf8',
  );

  assert.match(source, /innerJoin\('p\.order', 'o'\)/);
  assert.match(source, /SUM\(p\.amount\)/);
  assert.match(source, /p\.paid_at >= CAST\(:fromKey AS date\)/);
  assert.match(
    source,
    /p\.paid_at < CAST\(:toKey AS date\) \+ INTERVAL '1 day'/,
  );
  assert.match(source, /o\.status != 'CANCELLED'/);
  assert.match(source, /groupBy\('p\.method'\)/);
});

test('AI store context uses actual stock and net sales by business date', () => {
  const source = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'services', 'ai.service.ts'),
    'utf8',
  );

  assert.match(source, /COALESCE\(SUM\(s\.quantity\), 0\) AS current_stock/);
  assert.match(source, /HAVING COALESCE\(SUM\(s\.quantity\), 0\) <= p\.min_stock/);
  assert.match(source, /order_date >= NOW\(\) - INTERVAL '30 days'/);
  assert.match(source, /return_date >= NOW\(\) - INTERVAL '30 days'/);
  assert.match(source, /JOIN sales_orders o/);
  assert.match(source, /sales\.gross_revenue - returns\.return_value AS net_revenue/);
  assert.doesNotMatch(source, /created_at >= NOW\(\) - INTERVAL '30 days'/);
});

test('tax reports exclude cancelled and rejected returns', () => {
  const source = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'services', 'tax.service.ts'),
    'utf8',
  );

  assert.ok(
    (source.match(/status: Not\(In\(\['CANCELLED', 'REJECTED'\]\)\)/g) || [])
      .length >= 4,
  );
  assert.match(source, /relations: \['order'\]/);
  assert.match(source, /salesReturn\.order\?\.totalAmount/);
});
