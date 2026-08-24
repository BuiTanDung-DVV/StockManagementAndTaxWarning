const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

const { normalizeDatabaseBusinessDate } = require(path.join(
  __dirname,
  '..',
  'dist',
  'system',
  'data-freshness.utils.js',
));

test('database date is returned as the Vietnam business date', () => {
  assert.equal(
    normalizeDatabaseBusinessDate(new Date('2026-07-27T17:00:00.000Z')),
    '2026-07-28',
  );
});

test('missing or invalid database dates stay unknown', () => {
  assert.equal(normalizeDatabaseBusinessDate(null), null);
  assert.equal(normalizeDatabaseBusinessDate('not-a-date'), null);
});
