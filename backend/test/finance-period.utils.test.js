const test = require('node:test');
const assert = require('node:assert/strict');

const {
  normalizeCashTransactionQuery,
  resolveCurrentMonthExpensePeriod,
} = require('../dist/finance/finance-period.utils.js');

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
