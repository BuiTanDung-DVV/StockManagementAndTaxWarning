const test = require('node:test');
const assert = require('node:assert/strict');

const {
  InventoryMasterInputError,
  normalizeWarehouseInput,
} = require('../dist/inventory/inventory-master-input.utils');
const {
  ProductInputError,
  normalizeBatchInput,
  normalizeCategoryInput,
  normalizeCostItemInput,
  normalizeCostTypeInput,
  normalizeUnitConversionInput,
} = require('../dist/product/product-input.utils');

test('warehouse and category reject lifecycle and scope fields', () => {
  assert.deepEqual(normalizeWarehouseInput({ name: ' Kho chính ', address: ' Hà Nội ' }), {
    name: 'Kho chính',
    address: 'Hà Nội',
  });
  assert.throws(() => normalizeWarehouseInput({ name: 'Kho', shopId: 9 }), InventoryMasterInputError);
  assert.throws(() => normalizeCategoryInput({ name: 'Xi măng', isActive: false }), ProductInputError);
});

test('batch only accepts valid dates, quantities and business fields', () => {
  const batch = normalizeBatchInput({
    batchNumber: 'LO-01',
    manufacturingDate: '2026-08-01',
    expiryDate: '2027-08-01',
    quantity: 20,
    costPrice: 72000,
  });
  assert.equal(batch.quantity, 20);
  assert.throws(() => normalizeBatchInput({ batchNumber: 'X', quantity: -1 }), ProductInputError);
  assert.throws(() => normalizeBatchInput({ batchNumber: 'X', quantity: 1, shopId: 2 }), ProductInputError);
});

test('unit conversion and cost configuration validate server-owned contracts', () => {
  assert.deepEqual(normalizeUnitConversionInput({
    fromUnit: 'Thùng',
    toUnit: 'Cái',
    conversionRate: 12,
  }), {
    fromUnit: 'Thùng',
    toUnit: 'Cái',
    conversionRate: 12,
    sellingPricePerUnit: null,
  });
  assert.equal(normalizeCostTypeInput({ name: 'Vận chuyển' }).sortOrder, 0);
  assert.equal(normalizeCostItemInput(2, 10, 'PERCENTAGE', null).amount, 10);
  assert.throws(() => normalizeCostItemInput(2, 101, 'PERCENTAGE', null), ProductInputError);
});
