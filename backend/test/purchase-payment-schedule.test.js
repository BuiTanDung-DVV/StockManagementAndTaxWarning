const test = require('node:test');
const assert = require('node:assert/strict');

const { buildPurchasePaymentSchedule } = require('../dist/finance/purchase-payment-schedule.utils.js');

const roundMoney = (value) => Math.round(value / 1000) * 1000;

test('staged purchase payments preserve the total and stay within the period', () => {
  const anchor = new Date('2026-08-08T07:30:00+07:00');
  const lastAllowed = new Date('2026-08-30T23:59:59+07:00');
  const schedule = buildPurchasePaymentSchedule(anchor, 470_000_000, lastAllowed, roundMoney);

  assert.equal(schedule.length, 6);
  assert.equal(schedule.reduce((sum, item) => sum + item.amount, 0), 470_000_000);
  assert.ok(schedule.every((item) => item.date >= anchor && item.date <= lastAllowed));
  assert.ok(schedule.every((item, index) => index === 0 || item.date >= schedule[index - 1].date));
  assert.ok(Math.max(...schedule.map((item) => item.amount)) <= 85_000_000);
});

test('late-period payments are clamped instead of creating future transactions', () => {
  const anchor = new Date('2026-08-28T07:30:00+07:00');
  const lastAllowed = new Date('2026-08-28T17:30:00+07:00');
  const schedule = buildPurchasePaymentSchedule(anchor, 125_000_000, lastAllowed, roundMoney);

  assert.equal(schedule.reduce((sum, item) => sum + item.amount, 0), 125_000_000);
  assert.ok(schedule.every((item) => item.date <= lastAllowed));
});

test('near-period-end payments use distinct available dates without bunching', () => {
  const anchor = new Date('2026-08-26T07:30:00+07:00');
  const lastAllowed = new Date('2026-08-28T23:59:59+07:00');
  const schedule = buildPurchasePaymentSchedule(anchor, 390_000_000, lastAllowed, roundMoney);

  assert.equal(schedule.length, 3);
  assert.equal(schedule.reduce((sum, item) => sum + item.amount, 0), 390_000_000);
  assert.equal(new Set(schedule.map((item) => item.date.toISOString())).size, 3);
  assert.ok(Math.max(...schedule.map((item) => item.amount)) <= 140_000_000);
});
