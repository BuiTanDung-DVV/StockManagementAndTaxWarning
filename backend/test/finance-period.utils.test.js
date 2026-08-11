const test = require('node:test');
const assert = require('node:assert/strict');

const {
  buildVietnamPeriodKeys,
  normalizeCashTransactionQuery,
  resolveCurrentMonthExpensePeriod,
  resolveVietnamBusinessDayEnd,
  resolveVietnamBusinessDayPeriod,
} = require('../dist/finance/finance-period.utils.js');
const fs = require('node:fs');
const path = require('node:path');

test('cash transaction query uses inclusive Vietnam business-day boundaries', () => {
  const query = normalizeCashTransactionQuery({
    page: 0,
    limit: 500,
    type: ' EXPENSE ',
    category: ' SALARY ',
    from: '2026-08-01',
    to: '2026-08-31',
  });

  assert.equal(query.page, 1);
  assert.equal(query.limit, 100);
  assert.equal(query.type, 'EXPENSE');
  assert.equal(query.category, 'SALARY');
  assert.equal(query.fromDate.toISOString(), '2026-07-31T17:00:00.000Z');
  assert.equal(query.toDate.toISOString(), '2026-08-31T16:59:59.999Z');
});

test('expense period defaults to the current month and rejects reversed dates', () => {
  const now = new Date('2026-08-15T03:30:00.000Z');
  const period = resolveCurrentMonthExpensePeriod(undefined, undefined, now);

  assert.equal(period.fromDate.toISOString(), '2026-07-31T17:00:00.000Z');
  assert.equal(period.toDate.toISOString(), '2026-08-15T16:59:59.999Z');

  assert.throws(
    () => normalizeCashTransactionQuery({
      from: '2026-08-20',
      to: '2026-08-01',
    }),
    /Invalid reporting period/,
  );
});

test('debt aging uses the end of the selected Vietnam business day', () => {
  assert.equal(
    resolveVietnamBusinessDayEnd('2026-08-09').toISOString(),
    '2026-08-09T16:59:59.999Z',
  );
  assert.equal(
    resolveVietnamBusinessDayEnd(
      undefined,
      new Date('2026-08-09T18:30:00.000Z'),
    ).toISOString(),
    '2026-08-10T16:59:59.999Z',
  );
});

test('daily closing uses the complete selected Vietnam business day', () => {
  const period = resolveVietnamBusinessDayPeriod('2026-08-09');

  assert.equal(period.businessDate, '2026-08-09');
  assert.equal(period.fromDate.toISOString(), '2026-08-08T17:00:00.000Z');
  assert.equal(period.toDate.toISOString(), '2026-08-09T16:59:59.999Z');
});

test('chart labels are filled from Vietnam calendar dates, not server local dates', () => {
  const fromDate = new Date('2026-07-31T17:00:00.000Z');
  const toDate = new Date('2026-08-02T16:59:59.999Z');

  assert.deepEqual(
    buildVietnamPeriodKeys(fromDate, toDate, 'day'),
    ['2026-08-01', '2026-08-02'],
  );
  assert.deepEqual(
    buildVietnamPeriodKeys(
      new Date('2025-11-30T17:00:00.000Z'),
      new Date('2026-01-31T16:59:59.999Z'),
      'month',
    ),
    ['2025-12', '2026-01'],
  );
});

test('sales and finance summaries share Vietnam business-day boundaries', () => {
  const financeSource = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'services', 'finance.service.ts'),
    'utf8',
  );
  const salesSource = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'services', 'sales.service.ts'),
    'utf8',
  );

  assert.doesNotMatch(financeSource, /from \? new Date\(from\)/);
  assert.doesNotMatch(salesSource, /from \? new Date\(from\)/);
  assert.match(financeSource, /resolveCurrentMonthExpensePeriod\(from, to\)/);
  assert.match(salesSource, /resolveCurrentMonthExpensePeriod\(from, to\)/);
  assert.match(financeSource, /AT TIME ZONE 'Asia\/Ho_Chi_Minh'/);
  assert.match(salesSource, /vietnamDateKey\(fromDate\)/);
  assert.match(salesSource, /CAST\(:fromKey AS date\)/);
  assert.doesNotMatch(salesSource, /TO_CHAR\(o\.order_date AT TIME ZONE/);
  assert.match(financeSource, /buildVietnamPeriodKeys\(/);
  assert.match(salesSource, /buildVietnamPeriodKeys\(/);
});
