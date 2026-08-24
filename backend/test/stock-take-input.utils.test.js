const test = require('node:test');
const assert = require('node:assert/strict');

const {
  StockTakeInputError,
  normalizeStockTakeCreateInput,
  normalizeStockTakeStatusInput,
} = require('../dist/inventory/stock-take-input.utils');

test('stock take create accepts actual counts but never client system counts', () => {
  const normalized = normalizeStockTakeCreateInput({
    warehouseId: 3,
    stockTakeDate: '2026-08-13T09:30:00.000Z',
    notes: 'Kiểm kê cuối ngày',
    items: [{ productId: 10, actualQty: 8 }],
  });
  assert.equal(normalized.stockTakeDate, '2026-08-13');
  assert.deepEqual(normalized.items, [{ productId: 10, actualQty: 8, notes: null }]);
  assert.throws(
    () => normalizeStockTakeCreateInput({
      warehouseId: 3,
      stockTakeDate: '2026-08-13',
      items: [{ productId: 10, systemQty: 999, actualQty: 8 }],
    }),
    StockTakeInputError,
  );
});

test('stock take create rejects duplicate products and negative counts', () => {
  assert.throws(
    () => normalizeStockTakeCreateInput({
      stockTakeDate: '2026-08-13',
      items: [
        { productId: 10, actualQty: 1 },
        { productId: 10, actualQty: 2 },
      ],
    }),
    StockTakeInputError,
  );
  assert.throws(
    () => normalizeStockTakeCreateInput({
      stockTakeDate: '2026-08-13',
      items: [{ productId: 10, actualQty: -1 }],
    }),
    StockTakeInputError,
  );
});

test('stock take status only accepts terminal workflow actions', () => {
  assert.deepEqual(normalizeStockTakeStatusInput({ status: 'completed' }), {
    status: 'COMPLETED',
    notes: null,
  });
  assert.throws(() => normalizeStockTakeStatusInput({ status: 'DRAFT' }), StockTakeInputError);
  assert.throws(() => normalizeStockTakeStatusInput({ status: 'COMPLETED', approvedBy: 1 }), StockTakeInputError);
});
