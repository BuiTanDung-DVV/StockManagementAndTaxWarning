const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const fs = require('node:fs');

const { normalizeInvoiceDataQuality } = require(path.join(
  __dirname,
  '..',
  'dist',
  'finance',
  'invoice-data-quality.utils.js',
));

test('invoice quality converts database counters and totals all issue categories', () => {
  const result = normalizeInvoiceDataQuality({
    checkedInvoices: '120',
    missingItemInvoices: '3',
    headerTotalMismatchInvoices: '4',
    headerSubtotalMismatchInvoices: '6',
    unallocatedDiscountInvoices: '8',
    headerTaxMismatchInvoices: '7',
    invalidLineItems: '1',
    lineSubtotalMismatchItems: '2',
    lineTaxMismatchItems: '5',
    firstInvoiceDate: new Date('2023-07-28T17:00:00.000Z'),
    lastInvoiceDate: '2026-07-27T17:00:00.000Z',
  });

  assert.deepEqual(result, {
    checkedInvoices: 120,
    missingItemInvoices: 3,
    headerTotalMismatchInvoices: 4,
    headerSubtotalMismatchInvoices: 6,
    unallocatedDiscountInvoices: 8,
    headerTaxMismatchInvoices: 7,
    invalidLineItems: 1,
    lineSubtotalMismatchItems: 2,
    lineTaxMismatchItems: 5,
    issueCount: 36,
    hasIssues: true,
    firstInvoiceDate: '2023-07-29',
    lastInvoiceDate: '2026-07-28',
  });
});

test('invoice quality reports a clean empty period without false warnings', () => {
  assert.deepEqual(normalizeInvoiceDataQuality(), {
    checkedInvoices: 0,
    missingItemInvoices: 0,
    headerTotalMismatchInvoices: 0,
    headerSubtotalMismatchInvoices: 0,
    unallocatedDiscountInvoices: 0,
    headerTaxMismatchInvoices: 0,
    invalidLineItems: 0,
    lineSubtotalMismatchItems: 0,
    lineTaxMismatchItems: 0,
    issueCount: 0,
    hasIssues: false,
    firstInvoiceDate: null,
    lastInvoiceDate: null,
  });
});

test('sales-order discounts are classified separately from unexplained invoice mismatch', () => {
  const service = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'services', 'finance.service.ts'),
    'utf8',
  );

  assert.match(service, /source_order\.discount_amount/);
  assert.match(service, /'unallocatedDiscountInvoices'/);
  assert.match(
    service,
    /headerSubtotalMismatchInvoices[\s\S]*?unallocatedDiscountInvoices/,
  );
});
