const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const service = fs.readFileSync(path.join(__dirname, '../src/services/finance.service.ts'), 'utf8');
const controller = fs.readFileSync(path.join(__dirname, '../src/controllers/finance.controller.ts'), 'utf8');
const provider = fs.readFileSync(path.join(__dirname, '../../lib/features/finance/providers/finance_provider.dart'), 'utf8');
const screen = fs.readFileSync(path.join(__dirname, '../../lib/features/finance/presentation/purchase_no_invoice_screen.dart'), 'utf8');

test('purchase approval filter is applied before database pagination', () => {
  assert.match(controller, /req\.query\.status as string/);
  assert.match(service, /purchase\.approvalStatus = :status/);
  assert.match(service, /\.skip\(\(safePage - 1\) \* safeLimit\)/);
  assert.match(provider, /'status': \?status/);
  assert.match(screen, /purchasesNoInvoiceProvider\(\(page: _page, status: requestedStatus\)\)/);
  assert.doesNotMatch(screen, /List<Map<String, dynamic>> _filterItems/);
});

test('purchase approval totals cover the complete filtered database set', () => {
  assert.match(service, /SUM\(purchase_total\.totalAmount\)/);
  assert.match(service, /createQueryBuilder\('purchase_total'\)/);
  assert.match(service, /filteredAmountTotal: Number/);
  assert.match(screen, /asNum\(data\['filteredAmountTotal'\]\)/);
});
