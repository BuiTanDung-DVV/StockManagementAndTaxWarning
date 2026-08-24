const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const source = (file) => fs.readFileSync(
  path.join(__dirname, '..', 'src', file),
  'utf8',
);

test('manual receivable collection is atomic and server controlled', () => {
  const service = source('services/customer.service.ts');

  assert.match(service, /collectManualReceivablePayment/);
  assert.match(service, /AppDataSource\.transaction\(async \(manager\)/);
  assert.match(service, /lock: \{ mode: 'pessimistic_write' \}/);
  assert.match(service, /manager\.save\(Receivable/);
  assert.match(service, /DebtPaymentHistory/);
  assert.match(service, /createCashTransaction[\s\S]*?'DEBT_COLLECTION'/);
  assert.match(service, /postJournal[\s\S]*?accountCode: '131'/);
  assert.match(service, /Linked receivable must use the sales order payment workflow/);
});

test('manual collection route requires customer edit permission', () => {
  const routes = source('routes/customer.routes.ts');
  const finance = source('services/finance.service.ts');

  assert.match(
    routes,
    /receivables\/:receivableId\/payments', requirePermission\('customers', 'edit'\)/,
  );
  assert.match(finance, /linkedRefTypes[\s\S]*?'DEBT_COLLECTION'/);
});
