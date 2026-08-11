const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const service = fs.readFileSync(
  path.join(__dirname, '..', 'src', 'services', 'finance.service.ts'),
  'utf8',
);

test('daily closing loads transactions by Vietnam day range instead of exact timestamp', () => {
  assert.match(service, /resolveVietnamBusinessDayPeriod\(date\)/);
  assert.match(
    service,
    /transactionDate: Between\(fromDate, toDate\)/,
  );
  assert.doesNotMatch(service, /transactionDate: d as any/);
  assert.doesNotMatch(service, /CAST\(t\.transaction_date AS DATE\)/);
});

test('daily closing counts real non-cancelled sales orders', () => {
  assert.match(service, /FROM sales_orders/);
  assert.match(service, /COUNT\(\*\)::int AS "orderCount"/);
  assert.match(service, /status, ''\)\) != 'CANCELLED'/);
  assert.match(service, /FROM sales_returns/);
});

test('daily closing financial totals are derived by the server', () => {
  assert.match(
    service,
    /const current = await this\.getDailyClosingByDate\(shopId, businessDate\)/,
  );
  assert.match(service, /totalSales: Number\(current\.totalSales \|\| 0\)/);
  assert.match(service, /totalReturns: Number\(current\.totalReturns \|\| 0\)/);
  assert.match(service, /orderCount: Number\(current\.orderCount \|\| 0\)/);
  assert.doesNotMatch(service, /create\(\{ \.\.\.dto, shopId \}\)/);
});
