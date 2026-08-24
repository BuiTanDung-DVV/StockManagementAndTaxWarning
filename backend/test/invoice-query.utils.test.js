const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

const { normalizeInvoiceListQuery } = require(path.join(
  __dirname,
  '..',
  'dist',
  'finance',
  'invoice-query.utils.js',
));

test('invoice list accepts a complete period and normalizes filters', () => {
  const query = normalizeInvoiceListQuery({
    page: 2,
    limit: 200,
    type: 'out',
    from: '2026-07-01',
    to: '2026-07-28',
  });

  assert.equal(query.page, 2);
  assert.equal(query.limit, 100);
  assert.equal(query.type, 'OUT');
  assert.ok(query.fromDate instanceof Date);
  assert.ok(query.toDate instanceof Date);
});

test('invoice list without dates explicitly means all periods', () => {
  const query = normalizeInvoiceListQuery({ page: 1, limit: 20 });
  assert.equal(query.fromDate, undefined);
  assert.equal(query.toDate, undefined);
});

test('invoice list rejects partial periods, reversed dates and invalid types', () => {
  assert.throws(
    () => normalizeInvoiceListQuery({ from: '2026-07-01' }),
    /đủ ngày bắt đầu và kết thúc/,
  );
  assert.throws(
    () => normalizeInvoiceListQuery({ from: '2026-08-01', to: '2026-07-01' }),
    /không hợp lệ/,
  );
  assert.throws(
    () => normalizeInvoiceListQuery({ type: 'OTHER' }),
    /Loại hóa đơn/,
  );
});
