const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const source = (file) => fs.readFileSync(
  path.join(__dirname, '..', 'src', file),
  'utf8',
);

// Source contracts only; real rollback/concurrency coverage lives in the
// authorized PostgreSQL verifier, not in these text assertions.
test('manual collection keeps transactional posting and the shared shop mutation guard', () => {
  const service = source('services/customer.service.ts');

  assert.match(service, /collectManualReceivablePayment/);
  assert.match(service, /AppDataSource\.transaction\(async \(manager\)/);
  assert.match(service, /await lockShopMutation\(manager, shopId\)/);
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
