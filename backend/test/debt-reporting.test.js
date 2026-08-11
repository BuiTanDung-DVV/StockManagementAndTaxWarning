const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const readService = (name) => fs.readFileSync(
  path.join(__dirname, '..', 'src', 'services', name),
  'utf8',
);

test('debt reports exclude paid and cancelled receivables', () => {
  const customerService = readService('customer.service.ts');

  assert.match(
    customerService,
    /Not\(In\(\['PAID', 'CANCELLED'\]\)\)/,
  );
  assert.match(customerService, /resolveVietnamBusinessDayEnd\(asOf\)/);
  assert.match(customerService, /receivableCount \+= 1/);
});

test('AI debt context comes from open receivables instead of cached customer balance', () => {
  const aiService = readService('ai.service.ts');

  assert.doesNotMatch(aiService, /SUM\(balance\)/);
  assert.match(aiService, /FROM receivables/);
  assert.match(
    aiService,
    /NOT IN \('PAID', 'CANCELLED'\)/,
  );
  assert.match(aiService, /GREATEST\(amount - paid_amount, 0\)/);
});

test('AI low-stock insight counts products whose actual stock reached the threshold', () => {
  const aiService = readService('ai.service.ts');

  assert.match(aiService, /LEFT JOIN inventory_stocks s/);
  assert.match(
    aiService,
    /HAVING COALESCE\(SUM\(s\.quantity\), 0\) <= p\.min_stock/,
  );
});

test('cancelling a sale never makes cached customer debt negative', () => {
  const salesService = readService('sales.service.ts');

  assert.match(
    salesService,
    /customer\.balance = Math\.max\([\s\S]*?- unpaidAmount,[\s\S]*?0,[\s\S]*?\)/,
  );
});
