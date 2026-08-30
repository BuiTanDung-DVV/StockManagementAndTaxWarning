const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const {
  calculateGrossMarginPercentage,
  calculateNetAmount,
  calculateRevenueGrowth,
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

test('gross margin preserves loss-making products', () => {
  assert.equal(calculateGrossMarginPercentage(1_000_000, 250_000), 25);
  assert.equal(calculateGrossMarginPercentage(1_000_000, -125_000), -12.5);
  assert.equal(calculateGrossMarginPercentage(0, -125_000), 0);
});

test('product growth is calculated by backend with explicit comparison status', () => {
  assert.deepEqual(calculateRevenueGrowth(150, 100, true), {
    growthPct: 50,
    growthStatus: 'COMPARABLE',
  });
  assert.deepEqual(calculateRevenueGrowth(75, 100, true), {
    growthPct: -25,
    growthStatus: 'COMPARABLE',
  });
  assert.deepEqual(calculateRevenueGrowth(100, null, true), {
    growthPct: null,
    growthStatus: 'NEW',
  });
  assert.deepEqual(calculateRevenueGrowth(100, 0, true), {
    growthPct: null,
    growthStatus: 'NO_BASE',
  });
  assert.deepEqual(calculateRevenueGrowth(100, 80, false), {
    growthPct: null,
    growthStatus: 'NOT_REQUESTED',
  });
  assert.throws(
    () => calculateRevenueGrowth(Number.NaN, 100, true),
    /Invalid current product revenue/,
  );
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
  assert.match(source, /\.orderBy\('o\.orderDate', 'DESC'\)/);
  assert.match(source, /\.addOrderBy\('o\.id', 'DESC'\)/);
  assert.doesNotMatch(source, /\.orderBy\('o\.createdAt', 'DESC'\)/);
  assert.match(source, /vietnameseSearchExpression\('o\.orderCode'\)/);
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
  assert.match(source, /const cogsResult = await this\.cogsService\.calculateCOGS\(/);
  assert.doesNotMatch(
    source,
    /calculateCOGS\([\s\S]{0,500}?catch\s*\{[\s\S]{0,200}?product\.costPrice/,
  );
});

test('sale aborts when a concurrent request already consumed an inventory lot', () => {
  const source = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'services', 'cogs.service.ts'),
    'utf8',
  );

  assert.match(source, /const result = await qb/);
  assert.match(source, /result\.affected !== 1/);
  assert.match(source, /Inventory lot \$\{d\.lotId\} no longer has enough stock/);
});

test('COGS never fills missing inventory lots with a product master price', () => {
  const source = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'services', 'cogs.service.ts'),
    'utf8',
  );

  assert.match(source, /Inventory lots for product \$\{productId\} are short by/);
  assert.match(source, /if \(totalQty < quantity\)/);
  assert.doesNotMatch(source, /fallbackPrice|Fallback: dùng cost_price từ products/);
  assert.doesNotMatch(source, /return 'AVG'; \/\/ Default fallback/);
});

test('inventory lots cannot be written outside controlled inventory workflows', () => {
  const service = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'services', 'cogs.service.ts'),
    'utf8',
  );
  const routes = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'routes', 'cogs.routes.ts'),
    'utf8',
  );

  assert.doesNotMatch(routes, /router\.post\('\/lots'/);
  assert.match(service, /Product does not belong to the active shop/);
  assert.match(service, /Inventory lot quantity must be greater than 0/);
  assert.match(service, /Inventory lot cost must be non-negative/);
  assert.match(service, /Product has no remaining inventory lots/);
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
  assert.match(
    source,
    /\(sold\.gross_value - COALESCE\(returned\.return_value, 0\)\) -\s*\(sold\.gross_cogs - COALESCE\(returned\.return_cogs, 0\)\) AS gross_profit/,
  );
  assert.doesNotMatch(
    source,
    /GREATEST\(\s*\(sold\.gross_value[\s\S]*?AS gross_profit/,
  );
  assert.match(source, /const previousValue = p\.previous_value == null/);
  assert.match(source, /calculateRevenueGrowth\(/);
  assert.match(source, /previousPeriod !== null/);
  assert.match(source, /\.\.\.growth/);
  assert.match(source, /marginPct: calculateGrossMarginPercentage\(/);
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

test('daily sales chart exposes database revenue, COGS and gross profit', () => {
  const source = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'services', 'sales.service.ts'),
    'utf8',
  );

  assert.match(source, /SUM\(o\.total_cogs\)/);
  assert.match(source, /AS "returnedCogs"/);
  assert.match(source, /cogs: Number\(d\.cogs \|\| 0\)/);
  assert.match(source, /grossProfit,/);
  assert.match(source, /marginPct: revenue > 0/);
});

test('paid orders do not fail because of an existing customer credit balance', () => {
  const source = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'services', 'sales.service.ts'),
    'utf8',
  );

  assert.match(source, /customer\s*&&\s*unpaidAmount > 0/);
  assert.match(source, /projectedExposure = currentExposure \+ newDebt/);
});

test('sales creation persists product foreign keys and unique linked cash codes', () => {
  const source = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'services', 'sales.service.ts'),
    'utf8',
  );

  assert.match(source, /productId: product\.id/);
  assert.match(source, /transactionCode: `TS\$\{shopId\}\$\{savedOrder\.id\}`/);
});

test('AI store context uses actual stock and net sales by business date', () => {
  const source = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'services', 'ai.service.ts'),
    'utf8',
  );

  assert.match(source, /COALESCE\(SUM\(s\.quantity\), 0\) AS current_stock/);
  assert.match(source, /HAVING COALESCE\(SUM\(s\.quantity\), 0\) <= p\.min_stock/);
  assert.match(source, /private salesService = new SalesService\(\)/);
  assert.match(source, /this\.salesService\.summary\(/);
  assert.match(source, /vietnamDateKey\(fromDate\)/);
  assert.match(source, /vietnamDateKey\(toDate\)/);
  assert.doesNotMatch(source, /sales\.gross_revenue - returns\.return_value/);
  assert.doesNotMatch(source, /created_at >= NOW\(\) - INTERVAL '30 days'/);
});

test('tax reports use the same database revenue basis as sales', () => {
  const taxSource = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'services', 'tax.service.ts'),
    'utf8',
  );

  assert.match(taxSource, /private salesService = new SalesService\(\)/);
  assert.match(taxSource, /this\.salesService\.summary\(shopId, from, to\)/);
  assert.match(taxSource, /this\.getRevenueBasis\(shopId, from, to\)/);
  assert.doesNotMatch(taxSource, /salesReturn\.order\?\.totalAmount/);
});
