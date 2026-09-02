const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const {
  buildAllocatedMerchandiseRevenueSql,
  calculateAllocatedMerchandiseRevenue,
  calculateSalesAccountingSplit,
  calculateSalesTaxLines,
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

test('sales tax is recalculated from database line rates after discount allocation', () => {
  assert.deepEqual(
    calculateSalesTaxLines(
      [
        { subtotal: 600_000, taxRate: 10 },
        { subtotal: 400_000, taxRate: 5 },
      ],
      1_000_000,
      100_000,
    ),
    {
      lines: [
        { subtotal: 600_000, taxRate: 10, taxAmount: 54_000 },
        { subtotal: 400_000, taxRate: 5, taxAmount: 18_000 },
      ],
      taxAmount: 72_000,
    },
  );
});

test('sales tax rejects an invalid rate loaded from database', () => {
  assert.throws(
    () => calculateSalesTaxLines([{ subtotal: 100, taxRate: 101 }], 100, 0),
    /Product tax rate in database is invalid/,
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
  assert.match(source, /refundShippingFee === true/);
  assert.match(source, /Refund amount does not match the selected shipping-fee option/);
  assert.match(source, /accountCode: '3388'/);
  assert.match(source, /accountCode: '3331'/);
  assert.match(source, /accountCode: '131'/);
  assert.match(source, /paymentLedgerAccountCode\(refund\.method\)/);
  assert.match(source, /accountCode: '632'/);
});

test('sales summary reports net merchandise revenue without output VAT', () => {
  const sales = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'services', 'sales.service.ts'),
    'utf8',
  );
  assert.match(sales, /SUM\(o\.subtotal - o\.discount_amount\)/);
  assert.match(sales, /JOIN sales_return_items ri ON ri\.return_id = r\.id/);
  assert.match(sales, /buildAllocatedMerchandiseRevenueSql\(\s*'ri\.subtotal'/);
  assert.match(sales, /sold_item\.tax_amount \* ri\.quantity \/ sold_item\.quantity/);
  assert.doesNotMatch(
    sales,
    /SUM\(returnedOrder\.subtotal - returnedOrder\.discount_amount\)/,
  );
  assert.match(sales, /addSelect\('COALESCE\(SUM\(o\.tax_amount\), 0\)'/);
  assert.match(sales, /SELECT SUM\(r\.refund_amount\)/);
  assert.match(sales, /grossProfit: netSalesRevenue - totalCogs/);
  assert.match(sales, /totalRevenue: grossChargedAmount - returnChargedAmount|const totalRevenue = grossChargedAmount - returnChargedAmount/);
});
