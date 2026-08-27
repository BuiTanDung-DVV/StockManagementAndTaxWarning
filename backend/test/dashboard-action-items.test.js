const test = require('node:test');
const assert = require('node:assert/strict');

const {
  lowStockActionCopy,
  scorePriority,
  sortDashboardActionItems,
  taxConfigurationActionDetail,
} = require('../dist/dashboard/action-center.utils');
const {
  permittedDashboardShopIds,
} = require('../dist/dashboard/action-access.utils');

const item = (actionKey, severity, priorityScore, dueAt = null) => ({
  actionKey,
  severity,
  priorityScore,
  title: actionKey,
  detail: actionKey,
  badge: severity,
  dueAt,
});

test('action items are sorted by severity before score', () => {
  const sorted = sortDashboardActionItems([
    item('INFO_HIGH', 'INFO', 999),
    item('WARNING_LOW', 'WARNING', 1),
    item('HEALTHY', 'HEALTHY', 9999),
    item('CRITICAL', 'CRITICAL', 0),
  ]);
  assert.deepEqual(
    sorted.map((entry) => entry.actionKey),
    ['CRITICAL', 'WARNING_LOW', 'INFO_HIGH', 'HEALTHY'],
  );
});

test('equal severity uses score, due date, then action key', () => {
  const sorted = sortDashboardActionItems([
    item('B', 'WARNING', 20, '2026-08-20'),
    item('C', 'WARNING', 30, '2026-08-30'),
    item('A', 'WARNING', 20, '2026-08-20'),
    item('D', 'WARNING', 20, null),
  ]);
  assert.deepEqual(
    sorted.map((entry) => entry.actionKey),
    ['C', 'A', 'B', 'D'],
  );
});

test('priority score increases with actual impact signals', () => {
  const baseline = scorePriority({ affectedCount: 1 });
  const overdue = scorePriority({ affectedCount: 1, daysOverdue: 30 });
  const highImpact = scorePriority({
    affectedCount: 10,
    daysOverdue: 30,
    affectedAmount: 500000000,
    stockDeficit: 100,
  });
  assert.ok(overdue > baseline);
  assert.ok(highImpact > overdue);
});

test('action-center copy never exposes database field names or mixed-unit deficit', () => {
  const stockCopy = lowStockActionCopy(1);
  const taxDetail = taxConfigurationActionDetail();

  assert.equal(
    stockCopy.title,
    '1 sản phẩm đã chạm hoặc thấp hơn định mức tồn',
  );
  assert.doesNotMatch(stockCopy.detail, /min_stock|đơn vị/i);
  assert.doesNotMatch(taxDetail, /TAX_|DB|database/i);
  assert.match(taxDetail, /Cài đặt thuế/);
});

test('all-shops scope keeps only shops with the requested domain permission', () => {
  const permitted = permittedDashboardShopIds([
    { shopId: 1, memberType: 'OWNER' },
    {
      shopId: 2,
      memberType: 'EMPLOYEE',
      role: { shopId: 2, permissions: { inventory: 'view' } },
    },
    {
      shopId: 3,
      memberType: 'EMPLOYEE',
      role: { shopId: 3, permissions: { finance: 'full' } },
    },
  ], 'inventory');
  assert.deepEqual(permitted, [1, 2]);
});

test('a role from another shop cannot broaden action-center access', () => {
  const permitted = permittedDashboardShopIds([
    {
      shopId: 8,
      memberType: 'EMPLOYEE',
      role: { shopId: 9, permissions: { customers: 'full' } },
    },
  ], 'customers');
  assert.deepEqual(permitted, []);
});
