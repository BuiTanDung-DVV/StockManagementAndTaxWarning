const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const { calculateRemainingPayable, classifyPayableAging } = require('../dist/supplier/payable-aging.utils');

const asOf = new Date('2026-08-11T16:59:59.999Z');

test('remaining payable is server-derived and never negative', () => {
  assert.equal(calculateRemainingPayable(1000000, 250000), 750000);
  assert.equal(calculateRemainingPayable(1000000, 1200000), 0);
  assert.equal(calculateRemainingPayable('invalid', 0), 0);
});

test('payable aging uses stable current, 30, 60 and over-60 buckets', () => {
  assert.equal(classifyPayableAging('2026-08-11', asOf), 'current');
  assert.equal(classifyPayableAging('2026-08-10', asOf), 'past30');
  assert.equal(classifyPayableAging('2026-07-12', asOf), 'past30');
  assert.equal(classifyPayableAging('2026-07-11', asOf), 'past60');
  assert.equal(classifyPayableAging('2026-06-12', asOf), 'past60');
  assert.equal(classifyPayableAging('2026-06-11', asOf), 'past90');
});

test('supplier payable report excludes settled rows and is shop scoped', () => {
  const source = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'services', 'supplier.service.ts'),
    'utf8',
  );
  assert.match(source, /shopId, status: Not\(In\(\['PAID', 'CANCELLED'\]\)\)/);
  assert.match(source, /calculateRemainingPayable/);
  assert.match(source, /resolveVietnamBusinessDayEnd\(asOf\)/);
  assert.match(source, /items\.slice\(0, 20\)/);

  const routeSource = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'routes', 'supplier.routes.ts'),
    'utf8',
  );
  assert.match(
    routeSource,
    /payables-aging', requirePermission\('finance', 'view'\)/,
  );

  const controllerSource = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'controllers', 'supplier.controller.ts'),
    'utf8',
  );
  assert.match(controllerSource, /isAllShops \|\| !Number\.isSafeInteger\(shopId\)/);
});
