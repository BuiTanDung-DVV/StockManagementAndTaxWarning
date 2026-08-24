const test = require('node:test');
const assert = require('node:assert/strict');

const {
  normalizeReceivableListQuery,
} = require('../dist/customer/receivable-list-query.utils');

test('receivable list query normalizes pagination and filters', () => {
  const query = normalizeReceivableListQuery({
    page: '2',
    limit: '500',
    search: '  Kiến   Tạo ',
    status: 'overdue',
    sort: 'remaining_desc',
    asOf: '2026-08-20',
  });

  assert.equal(query.page, 2);
  assert.equal(query.limit, 100);
  assert.equal(query.search, 'Kiến Tạo');
  assert.equal(query.status, 'OVERDUE');
  assert.equal(query.sort, 'REMAINING_DESC');
  assert.equal(query.asOf.toISOString(), '2026-08-20T16:59:59.999Z');
});

test('receivable list query rejects unsupported filters', () => {
  assert.throws(
    () => normalizeReceivableListQuery({ status: 'PAID' }),
    /status filter is invalid/,
  );
  assert.throws(
    () => normalizeReceivableListQuery({ sort: 'DROP_TABLE' }),
    /sort is invalid/,
  );
});
