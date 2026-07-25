const test = require('node:test');
const assert = require('node:assert/strict');

const {
    membershipHasAnyPermission,
    parseRolePermissions,
    permissionSatisfies,
    resolvePermissionLevel,
} = require('../dist/middleware/permission.utils');

test('owner always passes a module permission check', () => {
    assert.equal(
        membershipHasAnyPermission(
            { memberType: 'OWNER', role: null },
            ['finance'],
            'full',
        ),
        true,
    );
});

test('employee permission respects the required hierarchy', () => {
    const member = {
        memberType: 'EMPLOYEE',
        role: { permissions: JSON.stringify({ customers: 'view' }) },
    };

    assert.equal(
        membershipHasAnyPermission(member, ['customers'], 'view'),
        true,
    );
    assert.equal(
        membershipHasAnyPermission(member, ['customers'], 'edit'),
        false,
    );
});

test('invalid role JSON fails closed', () => {
    assert.deepEqual(parseRolePermissions('{invalid'), {});
    assert.equal(
        membershipHasAnyPermission(
            {
                memberType: 'EMPLOYEE',
                role: { permissions: '{invalid' },
            },
            ['inventory'],
            'view',
        ),
        false,
    );
});

test('legacy sales_view grants read-only sales access', () => {
    const permissions = parseRolePermissions(
        JSON.stringify({ sales_view: 'full' }),
    );

    assert.equal(resolvePermissionLevel(permissions, 'sales'), 'view');
    assert.equal(
        permissionSatisfies(
            resolvePermissionLevel(permissions, 'sales'),
            'edit',
        ),
        false,
    );
});

test('legacy pos permission remains compatible with sales writes', () => {
    const member = {
        memberType: 'EMPLOYEE',
        role: { permissions: JSON.stringify({ pos: 'edit' }) },
    };

    assert.equal(
        membershipHasAnyPermission(member, ['sales'], 'edit'),
        true,
    );
    assert.equal(
        membershipHasAnyPermission(member, ['sales'], 'full'),
        false,
    );
});

test('unrelated module permissions never satisfy the request', () => {
    const member = {
        memberType: 'EMPLOYEE',
        role: { permissions: JSON.stringify({ finance: 'full' }) },
    };

    assert.equal(
        membershipHasAnyPermission(member, ['suppliers'], 'view'),
        false,
    );
});

test('employee role from another shop never grants permissions', () => {
    const member = {
        memberType: 'EMPLOYEE',
        role: {
            shopId: 99,
            permissions: JSON.stringify({ finance: 'full' }),
        },
    };

    assert.equal(
        membershipHasAnyPermission(member, ['finance'], 'view', 10),
        false,
    );
    assert.equal(
        membershipHasAnyPermission(member, ['finance'], 'view', 99),
        true,
    );
});
