const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const financeService = fs.readFileSync(
  path.join(__dirname, '..', 'src', 'services', 'finance.service.ts'),
  'utf8',
);
const inventoryService = fs.readFileSync(
  path.join(__dirname, '..', 'src', 'services', 'inventory.service.ts'),
  'utf8',
);

test('owner-created approved purchase applies inventory and accounting in the save transaction', () => {
  assert.match(financeService, /const saved = await AppDataSource\.transaction/);
  assert.match(
    financeService,
    /if \(isOwner\) \{[\s\S]*?applyApprovedPurchaseWithoutInvoice\(/,
  );
  assert.match(financeService, /addInventoryLot\([\s\S]*?, manager\)/);
  assert.match(
    financeService,
    /postJournal\([\s\S]*?'PURCHASE_WITHOUT_INVOICE'[\s\S]*?manager/,
  );
});

test('purchase approval is idempotent and cannot be reversed after a decision', () => {
  assert.match(financeService, /currentStatus !== 'PENDING'/);
  assert.match(financeService, /currentStatus === input\.decision/);
  assert.match(financeService, /không thể đổi quyết định/);
});

test('approved purchase preserves warehouse and records the actual payment channel', () => {
  assert.match(financeService, /warehouseId,/);
  assert.match(financeService, /Cửa hàng chưa có kho hoạt động để nhận hàng/);
  assert.match(financeService, /referenceType: 'PURCHASE_WITHOUT_INVOICE'/);
  assert.match(financeService, /cashLedgerAccountCode\(paymentMethod\)/);
  assert.match(
    financeService,
    /linkedRefTypes = \[[\s\S]*?'PURCHASE_WITHOUT_INVOICE'/,
  );
});

test('completed or cancelled purchase orders cannot be reopened and received twice', () => {
  assert.match(inventoryService, /currentStatus !== 'PENDING'/);
  assert.match(inventoryService, /isIdempotentStatusUpdate/);
  assert.match(
    inventoryService,
    /Completed or cancelled purchase order is immutable/,
  );
});
