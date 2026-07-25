const test = require('node:test');
const assert = require('node:assert/strict');
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
