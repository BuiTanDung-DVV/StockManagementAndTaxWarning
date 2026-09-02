const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const service = fs.readFileSync(
  path.join(__dirname, '..', 'src', 'services', 'finance.service.ts'),
  'utf8',
);

test('daily closing loads DATE transactions by the Vietnam business-date key', () => {
  assert.match(service, /resolveVietnamBusinessDayPeriod\(date\)/);
  assert.match(
    service,
    /transactionDate: businessDate/,
  );
  assert.match(
    service,
    /const \{ businessDate, fromDate, toDate \} = resolveVietnamBusinessDayPeriod\(date\)/,
  );
  assert.doesNotMatch(service, /transactionDate: Between\(fromDate, toDate\)/);
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

test('daily closing explanation threshold comes from database configuration', () => {
  assert.match(service, /DAILY_CLOSING_EXPLANATION_THRESHOLD/);
  assert.match(service, /explanationThreshold/);
  assert.doesNotMatch(service, /Math\.abs\(cashDifference\) > 50000/);
});

test('daily closing adjustment is atomic and requires an active cash account', () => {
  assert.match(service, /return AppDataSource\.transaction\(async manager =>/);
  assert.match(service, /manager\.getRepository\(DailyClosing\)/);
  assert.match(service, /manager\.getRepository\(CashAccount\)/);
  assert.match(service, /accountType: 'CASH', isActive: true/);
  assert.match(service, /lock: \{ mode: 'pessimistic_write' \}/);
  assert.match(service, /this\.createCashTransaction\(shopId, txDto, manager\)/);
  assert.match(service, /referenceType: 'DAILY_CLOSING'/);
  assert.doesNotMatch(service, /cashAccounts\.find\(a => a\.accountType === 'CASH'\) \|\| cashAccounts\[0\]/);
});

test('daily closing history returns complete pagination metadata', () => {
  assert.match(
    service,
    /async getDailyClosings[\s\S]*?totalPages: Math\.ceil\(total \/ limit\)/,
  );
});
