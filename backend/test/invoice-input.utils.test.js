const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

const { normalizeInvoiceInput } = require(path.join(
  __dirname,
  '..',
  'dist',
  'finance',
  'invoice-input.utils.js',
));

test('invoice total is always subtotal plus tax', () => {
  const result = normalizeInvoiceInput({
    invoiceType: 'OUT',
    invoiceDate: '2026-08-09',
    partnerName: 'Công ty Kiến Tạo',
    subtotal: 1000000,
    taxAmount: 100000,
    totalAmount: 1,
  });

  assert.equal(result.totalAmount, 1100000);
});

test('partial invoice update preserves values and recalculates total', () => {
  const result = normalizeInvoiceInput(
    { taxAmount: 80000 },
    {
      invoiceType: 'IN',
      invoiceDate: new Date('2026-08-09'),
      partnerName: 'Nhà cung cấp A',
      subtotal: 1000000,
      taxAmount: 100000,
      paymentStatus: 'UNPAID',
    },
  );

  assert.equal(result.totalAmount, 1080000);
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
});
