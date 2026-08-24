const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { getMetadataArgsStorage } = require('typeorm');

require('../dist/config/db.config');

test('only one invoices entity is registered', () => {
  const invoiceTables = getMetadataArgsStorage().tables.filter(
    (table) => table.name === 'invoices',
  );
  assert.equal(invoiceTables.length, 1);
});

test('canonical invoice entity exposes invoice items relation', () => {
  const invoiceTable = getMetadataArgsStorage().tables.find(
    (table) => table.name === 'invoices',
  );
  assert.ok(invoiceTable);

  const itemRelations = getMetadataArgsStorage().relations.filter(
    (relation) =>
      relation.target === invoiceTable.target &&
      relation.propertyName === 'items',
  );
  assert.equal(itemRelations.length, 1);
});

test('system router no longer duplicates invoice endpoints', () => {
  const systemRouter = require('../dist/routes/system.routes').default;
  const paths = systemRouter.stack
    .map((layer) => layer.route?.path)
    .filter(Boolean);
  assert.equal(paths.some((path) => path.startsWith('/invoices')), false);
});

test('finance router does not expose mock e-invoice issuance', () => {
  const financeRouter = require('../dist/routes/finance.routes').default;
  const paths = financeRouter.stack
    .map((layer) => layer.route?.path)
    .filter(Boolean);
  assert.equal(paths.includes('/invoices/:id/issue'), false);
});

test('linked invoices cannot be edited or deleted outside source documents', () => {
  const source = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'services', 'finance.service.ts'),
    'utf8',
  );
  assert.match(source, /Linked invoice must be updated from its source document/);
  assert.match(source, /Linked invoice must be deleted from its source document/);
  assert.match(source, /Invoice source reference is server-controlled/);
});

test('manual invoice deletion removes detail rows in the same transaction', () => {
  const source = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'services', 'finance.service.ts'),
    'utf8',
  );
  assert.match(
    source,
    /manager\.getRepository\(InvoiceItem\)\.delete\(\{ invoice: \{ id \} \}\)/,
  );
  assert.match(source, /async deleteInvoice[\s\S]*AppDataSource\.transaction/);
});
