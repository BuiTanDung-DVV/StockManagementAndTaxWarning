const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

const {
  normalizeCashflowForecastInput,
} = require(path.join(
  __dirname,
  '..',
  'dist',
  'finance',
  'cashflow-forecast.utils.js',
));

test('forecast balance is always calculated from income minus expense', () => {
  const normalized = normalizeCashflowForecastInput({
    forecastDate: '2026-08-10',
    expectedIncome: 15000000,
    expectedExpense: 9000000,
    expectedBalance: 999999999,
  });

  assert.equal(normalized.expectedBalance, 6000000);
});

test('partial forecast update recalculates balance from persisted values', () => {
  const normalized = normalizeCashflowForecastInput(
    { expectedExpense: 12000000 },
    {
      forecastDate: new Date('2026-08-10'),
      expectedIncome: 15000000,
      expectedExpense: 9000000,
    },
  );

  assert.equal(normalized.expectedIncome, 15000000);
  assert.equal(normalized.expectedBalance, 3000000);
});

test('forecast rejects invalid dates and negative amounts', () => {
  assert.throws(
    () => normalizeCashflowForecastInput({ forecastDate: 'invalid' }),
    /Ngày dự báo không hợp lệ/,
  );
  assert.throws(
    () => normalizeCashflowForecastInput({
      forecastDate: '2026-08-10',
      expectedIncome: -1,
    }),
    /Thu dự kiến phải là số không âm/,
  );
});
