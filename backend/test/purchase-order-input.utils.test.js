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

test('purchase quantities, money, calendar dates and text cannot be coerced into valid input', () => {
  const base = { supplierId: 2, orderDate: '2026-08-13', items: [{ productId: 5, quantity: 1, unitPrice: 2 }] };
  for (const patch of [
    { supplierId: true }, { warehouseId: [] }, { notes: {} }, { invoiceNumber: 123 },
    { orderDate: '2026-02-30' }, { paymentDueDate: '2026-02-30' },
    ...[{ productId: true }, { quantity: true }, { quantity: 0.5 }, { quantity: 2147483648 },
      { unitPrice: true }, { unitPrice: '0.001' }, { quantity: 2, unitPrice: 9999999999999 }]
      .map(line => ({ items: [{ ...base.items[0], ...line }] })),
  ]) assert.throws(() => normalizePurchaseOrderCreateInput({ ...base, ...patch }), PurchaseOrderInputError);
  assert.throws(() => normalizePurchaseOrderUpdateInput({ status: {} }), PurchaseOrderInputError);
});

test('purchase input retains valid exact cents and ISO dates', () => {
  const value = normalizePurchaseOrderCreateInput({ supplierId: '2', orderDate: '2026-08-13T09:00:00.000Z', paymentDueDate: '2026-08-15', items: [{ productId: '5', quantity: '3', unitPrice: '10.01' }] });
  assert.deepEqual(value.items, [{ productId: 5, quantity: 3, unitPrice: 10.01 }]);
  assert.equal(value.paymentDueDate, '2026-08-15');
});
