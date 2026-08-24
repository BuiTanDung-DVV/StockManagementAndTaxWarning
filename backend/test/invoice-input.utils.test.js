const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

const { normalizeInvoiceInput, normalizeInvoiceItems } = require(path.join(
  __dirname,
  '..',
  'dist',
  'finance',
  'invoice-input.utils.js',
));

test('invoice total subtracts discount before adding tax', () => {
  const result = normalizeInvoiceInput({
    invoiceType: 'OUT',
    invoiceDate: '2026-08-09',
    partnerName: 'Công ty Kiến Tạo',
    subtotal: 1000000,
    discountAmount: 100000,
    taxAmount: 100000,
    totalAmount: 1,
  });

  assert.equal(result.totalAmount, 1000000);
});

test('partial invoice update preserves values and recalculates total', () => {
  const result = normalizeInvoiceInput(
    { taxAmount: 80000 },
    {
      invoiceType: 'IN',
      invoiceDate: new Date('2026-08-09'),
      partnerName: 'Nhà cung cấp A',
      subtotal: 1000000,
      discountAmount: 20000,
      taxAmount: 100000,
      paymentStatus: 'UNPAID',
    },
  );

  assert.equal(result.totalAmount, 1060000);
});

test('invoice rejects invalid type, date and amounts', () => {
  const base = {
    invoiceType: 'OUT',
    invoiceDate: '2026-08-09',
    partnerName: 'Khách hàng A',
    subtotal: 1000000,
  };
  assert.throws(
    () => normalizeInvoiceInput({ ...base, invoiceType: 'OTHER' }),
    /Loại hóa đơn/,
  );
  assert.throws(
    () => normalizeInvoiceInput({ ...base, subtotal: -1 }),
    /Tiền trước thuế/,
  );
  assert.throws(
    () => normalizeInvoiceInput({ ...base, discountAmount: 1000001 }),
    /Chiết khấu/,
  );
});

test('invoice items calculate authoritative line and header totals', () => {
  const result = normalizeInvoiceItems([
    {
      productId: 10,
      itemName: 'Sơn nội thất 18L',
      unit: 'Thùng',
      quantity: 2,
      unitPrice: 1000000,
      taxRate: 10,
      subtotal: 1,
      taxAmount: 1,
    },
    {
      itemName: 'Phí vận chuyển',
      unit: 'Lần',
      quantity: 1,
      unitPrice: 150000,
      taxRate: 0,
    },
  ]);

  assert.equal(result.subtotal, 2150000);
  assert.equal(result.taxAmount, 200000);
  assert.equal(result.totalAmount, 2350000);
  assert.equal(result.items[0].subtotal, 2000000);
});

test('invoice items reject empty or invalid business lines', () => {
  assert.throws(() => normalizeInvoiceItems([]), /ít nhất một dòng hàng/);
  assert.throws(
    () => normalizeInvoiceItems([{
      itemName: 'Xi măng',
      unit: 'Bao',
      quantity: 1.5,
      unitPrice: 90000,
    }]),
    /số nguyên lớn hơn 0/,
  );
  assert.throws(
    () => normalizeInvoiceItems([{
      itemName: 'Xi măng',
      unit: 'Bao',
      quantity: 1,
      unitPrice: 90000,
      taxRate: 101,
    }]),
    /từ 0 đến 100%/,
  );
});
