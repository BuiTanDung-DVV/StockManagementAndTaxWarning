const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const {
  buildAllocatedMerchandiseRevenueSql,
  calculateAllocatedMerchandiseRevenue,
  calculateSalesAccountingSplit,
} = require('../dist/sales/sales-accounting.utils.js');

test('sales accounting separates net revenue, output tax, cash and receivable', () => {
  assert.deepEqual(
    calculateSalesAccountingSplit(1_000_000, 100_000, 90_000, 400_000),
    {
      netSales: 900_000,
      taxAmount: 90_000,
      totalAmount: 990_000,
      paidAmount: 400_000,
      receivableAmount: 590_000,
    },
  );
});

test('sales accounting rejects invalid discount and payment amounts', () => {
  assert.throws(
    () => calculateSalesAccountingSplit(100, 101, 0, 0),
    /Discount exceeds subtotal/,
  );
  assert.throws(
    () => calculateSalesAccountingSplit(100, 0, 10, 111),
    /Paid amount exceeds order total/,
  );
});

test('order discount is allocated proportionally to product revenue', () => {
  assert.equal(
    calculateAllocatedMerchandiseRevenue(400_000, 1_000_000, 100_000),
    360_000,
  );
  assert.equal(calculateAllocatedMerchandiseRevenue(0, 0, 0), 0);
  assert.throws(
    () => calculateAllocatedMerchandiseRevenue(100, 100, 101),
    /Discount exceeds subtotal/,
  );
});

test('allocated revenue SQL guards zero subtotal and legacy excessive discounts', () => {
  const sql = buildAllocatedMerchandiseRevenueSql('oi.subtotal', 'o');
  assert.match(sql, /COALESCE\(o\.subtotal, 0\) <= 0/);
  assert.match(sql, /oi\.subtotal \* GREATEST/);
  assert.match(sql, /COALESCE\(o\.discount_amount, 0\) \/ o\.subtotal/);
  assert.throws(
    () => buildAllocatedMerchandiseRevenueSql('oi.subtotal; DROP TABLE x', 'o'),
    /Invalid sales allocation SQL identifier/,
  );
});

test('full return uses server prices and reverses every accounting component', () => {
  const source = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'services', 'sales.service.ts'),
    'utf8',
  );

  assert.match(source, /unitPrice: Number\(soldItem\.unitPrice \|\| 0\)/);
  assert.match(source, /subtotal: Number\(soldItem\.subtotal \|\| 0\)/);
  assert.match(source, /Full return must refund the full amount paid/);
  assert.match(source, /accountCode: '3331'/);
  assert.match(source, /accountCode: '131'/);
  assert.match(source, /paymentLedgerAccountCode\(refund\.method\)/);
  assert.match(source, /accountCode: '632'/);
});

test('return reporting reverses the returned order value, not only cash refunded', () => {
  const sales = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'services', 'sales.service.ts'),
    'utf8',
  );
  const tax = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'services', 'tax.service.ts'),
    'utf8',
  );

  assert.match(sales, /SUM\(returnedOrder\.total_amount\)/);
  assert.match(tax, /salesReturn\.order\?\.totalAmount/);
});
