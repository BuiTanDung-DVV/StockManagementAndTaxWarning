const test = require('node:test');
const assert = require('node:assert/strict');

const { classifyDebtAging } = require('../dist/customer/debt-aging.utils');

const asOf = new Date('2026-07-31T16:59:59.999Z');

test('debt aging uses stable current, 30, 60 and over-60 buckets', () => {
  assert.deepEqual(classifyDebtAging('2026-07-31', asOf), {
    bucket: 'current',
    daysOverdue: 0,
  });
  assert.deepEqual(classifyDebtAging('2026-07-01', asOf), {
    bucket: 'past30',
    daysOverdue: 30,
  });
  assert.deepEqual(classifyDebtAging('2026-06-01', asOf), {
    bucket: 'past60',
    daysOverdue: 60,
  });
  assert.deepEqual(classifyDebtAging('2026-05-31', asOf), {
    bucket: 'past90',
    daysOverdue: 61,
  });
});

test('future due dates stay current and invalid dates fail closed', () => {
  assert.deepEqual(classifyDebtAging('2026-08-15', asOf), {
    bucket: 'current',
    daysOverdue: 0,
  });
  assert.throws(() => classifyDebtAging('invalid', asOf), /Invalid debt aging date/);
});
