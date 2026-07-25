export type PermissionLevel = 'none' | 'view' | 'edit' | 'full';

const permissionHierarchy: PermissionLevel[] = [
    'none',
    'view',
    'edit',
    'full',
];

export interface PermissionMembership {
    memberType?: string | null;
    role?: {
        permissions?: string | Record<string, unknown> | null;
    } | null;
}

export const normalizePermissionLevel = (value: unknown): PermissionLevel => {
    if (typeof value !== 'string') return 'none';
    return permissionHierarchy.includes(value as PermissionLevel)
        ? (value as PermissionLevel)
        : 'none';
};

export const parseRolePermissions = (
    raw: string | Record<string, unknown> | null | undefined,
): Record<string, PermissionLevel> => {
    let parsed: Record<string, unknown> = {};

    if (typeof raw === 'string') {
        try {
            const value = JSON.parse(raw);
            if (value && typeof value === 'object' && !Array.isArray(value)) {
                parsed = value as Record<string, unknown>;
            }
        } catch {
            return {};
        }
    } else if (raw && typeof raw === 'object' && !Array.isArray(raw)) {
        parsed = raw;
    }

    return Object.fromEntries(
        Object.entries(parsed).map(([key, value]) => [
            key,
            normalizePermissionLevel(value),
        ]),
    );
};

const higherLevel = (
    left: PermissionLevel,
    right: PermissionLevel,
): PermissionLevel =>
    permissionHierarchy.indexOf(left) >= permissionHierarchy.indexOf(right)
        ? left
        : right;

export const resolvePermissionLevel = (
    permissions: Record<string, PermissionLevel>,
    key: string,
): PermissionLevel => {
    const direct = normalizePermissionLevel(permissions[key]);
    if (direct !== 'none') return direct;

    // Backward compatibility for roles saved by older Flutter releases.
    // `sales_view` must never grant write access even if an old role stored
    // an overly broad level for that key.
    if (key === 'sales') {
        const posLevel = normalizePermissionLevel(permissions.pos);
        const salesViewLevel =
            normalizePermissionLevel(permissions.sales_view) === 'none'
                ? 'none'
                : 'view';
        return higherLevel(posLevel, salesViewLevel);
    }

    return 'none';
};

export const permissionSatisfies = (
    actual: PermissionLevel,
    required: PermissionLevel,
): boolean =>
    permissionHierarchy.indexOf(actual) >=
    permissionHierarchy.indexOf(required);

export const membershipHasAnyPermission = (
    member: PermissionMembership,
    keys: string[],
    required: PermissionLevel,
): boolean => {
    if (member.memberType === 'OWNER') return true;

    const permissions = parseRolePermissions(member.role?.permissions);
    return keys.some((key) =>
        permissionSatisfies(
            resolvePermissionLevel(permissions, key),
            required,
        ),
    );
};
