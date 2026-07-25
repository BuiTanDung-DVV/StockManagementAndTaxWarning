const test = require('node:test');
const assert = require('node:assert/strict');

const {
    parseRequestedShopScope,
} = require('../dist/middleware/shop-scope.utils');

test('accepts a positive integer shop id and all scope', () => {
    assert.deepEqual(parseRequestedShopScope('42'), {
        kind: 'single',
        shopId: 42,
    });
    assert.deepEqual(parseRequestedShopScope(' all '), { kind: 'all' });
});

test('rejects ambiguous, invalid, and unsafe shop identifiers', () => {
    for (const value of [
        '1abc',
        '0',
        '-1',
        '1.5',
        '',
        '9007199254740992',
        ['1'],
        null,
        undefined,
    ]) {
        assert.equal(parseRequestedShopScope(value), null);
    }
});
