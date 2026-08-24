const test = require('node:test');
const assert = require('node:assert/strict');

const {
  PurchaseOrderInputError,
  normalizePurchaseOrderCreateInput,
  normalizePurchaseOrderUpdateInput,
} = require('../dist/inventory/purchase-order-input.utils');

test('purchase order input keeps identifiers and server-calculable lines', () => {
  const value = normalizePurchaseOrderCreateInput({
    supplierId: 2,
    warehouseId: 3,
    orderDate: '2026-08-13T09:00:00.000Z',
    notes: 'Nhập xi măng',
    items: [{ productId: 5, quantity: 10, unitPrice: 72000 }],
  });
  assert.equal(value.supplierId, 2);
  assert.deepEqual(value.items, [{ productId: 5, quantity: 10, unitPrice: 72000 }]);
});

test('purchase order input rejects totals, status and scope supplied on create', () => {
  for (const extra of [
    { totalAmount: 1 },
    { status: 'COMPLETED' },
    { shopId: 9 },
    { paidAmount: 1 },
  ]) {
    assert.throws(() => normalizePurchaseOrderCreateInput({
      supplierId: 2,
      orderDate: '2026-08-13',
      items: [{ productId: 5, quantity: 1, unitPrice: 2 }],
      ...extra,
    }), PurchaseOrderInputError);
  }
});

test('purchase order input rejects invalid lines and duplicate products', () => {
  assert.throws(() => normalizePurchaseOrderCreateInput({
    supplierId: 2,
    orderDate: '2026-08-13',
    items: [{ productId: 5, quantity: -1, unitPrice: 2 }],
  }), PurchaseOrderInputError);
  assert.throws(() => normalizePurchaseOrderCreateInput({
    supplierId: 2,
    orderDate: '2026-08-13',
    items: [
      { productId: 5, quantity: 1, unitPrice: 2 },
      { productId: 5, quantity: 1, unitPrice: 2 },
    ],
  }), PurchaseOrderInputError);
});

test('purchase order update only accepts workflow status and warehouse', () => {
  assert.deepEqual(normalizePurchaseOrderUpdateInput({ status: 'completed', warehouseId: 3 }), {
    status: 'COMPLETED',
    warehouseId: 3,
  });
  assert.throws(() => normalizePurchaseOrderUpdateInput({ status: 'COMPLETED', totalAmount: 1 }), PurchaseOrderInputError);
});
