const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

test('debt evidence routes require customer permissions', () => {
  const routes = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'routes', 'customer.routes.ts'),
    'utf8',
  );

  assert.match(routes, /customers\/:id\/evidence.*customers', 'view'/);
  assert.match(routes, /evidence-upload'.*customers', 'edit'/s);
  assert.doesNotMatch(routes, /presign/);
  assert.match(routes, /evidence-upload\/confirm.*customers', 'edit'/);
  assert.match(routes, /customers\/evidence\/:evidenceId.*customers', 'edit'/);
});

test('debt evidence only accepts an image owned by the active shop', () => {
  const service = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'services', 'customer.service.ts'),
    'utf8',
  );

  assert.match(service, /debtEvidenceImageKeyFromPublicUrl\(/);
  assert.match(service, /Evidence image is not owned by this shop/);
  assert.match(service, /findOne\(\{\s*where: \{ id: receivableId, shopId \}/);
});

test('deleting debt evidence removes the database row before best-effort storage cleanup', () => {
  const service = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'services', 'customer.service.ts'),
    'utf8',
  );
  const removeIndex = service.indexOf('await this.evidenceRepo.remove(evidence)');
  const cleanupIndex = service.indexOf(
    'deleteDebtEvidenceImageByUrl',
    removeIndex,
  );

  assert.ok(removeIndex >= 0);
  assert.ok(cleanupIndex > removeIndex);
});
