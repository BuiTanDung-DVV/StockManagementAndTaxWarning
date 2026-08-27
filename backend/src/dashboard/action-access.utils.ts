import {
    membershipHasAnyPermission,
    PermissionMembership,
} from '../middleware/permission.utils';

export interface DashboardMembership extends PermissionMembership {
    shopId: number;
}

export const permittedDashboardShopIds = (
    memberships: DashboardMembership[],
    permissionKey: string,
): number[] => [...new Set(
    memberships
        .filter((member) => membershipHasAnyPermission(
            member,
            [permissionKey],
            'view',
            member.shopId,
        ))
        .map((member) => member.shopId),
)];

