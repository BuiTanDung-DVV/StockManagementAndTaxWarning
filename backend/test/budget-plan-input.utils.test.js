const test = require('node:test');
const assert = require('node:assert/strict');

const { normalizeBudgetPlanInput } = require('../dist/finance/budget-plan-input.utils.js');

test('budget plan accepts valid planned values', () => {
  const result = normalizeBudgetPlanInput({
    name: 'Ngân sách tháng 8',
    period: 'month',
    startDate: '2026-08-01',
    endDate: '2026-08-31',
    plannedIncome: '100000000',
    plannedExpense: 70000000,
  });
  assert.equal(result.period, 'MONTH');
  assert.equal(result.plannedIncome, 100000000);
  assert.equal(result.plannedExpense, 70000000);
});
test('budget plan rejects invalid dates and amounts', () => {
  assert.throws(
    () => normalizeBudgetPlanInput({ name: 'A', startDate: '2026-08-31', endDate: '2026-08-01' }),
    /start date must not be after end date/,
  );
  assert.throws(
    () => normalizeBudgetPlanInput({ name: 'A', startDate: '2026-08-01', endDate: '2026-08-31', plannedIncome: -1 }),
    /must be non-negative/,
  );
});

test('actual budget values are not accepted as normalized input', () => {
  const result = normalizeBudgetPlanInput({
    name: 'A',
    startDate: '2026-08-01',
    endDate: '2026-08-31',
    actualIncome: 999999,
    actualExpense: 999999,
  });
  assert.equal(Object.hasOwn(result, 'actualIncome'), false);
  assert.equal(Object.hasOwn(result, 'actualExpense'), false);
});
