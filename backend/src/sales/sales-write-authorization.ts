import { EntityManager } from 'typeorm';
import { ShopMember } from '../shop/entities';
import { DailyClosing } from '../finance/entities';
import { membershipHasAnyPermission } from '../middleware/permission.utils';
import { vietnamDateKey } from '../finance/finance-period.utils';

export type SalesWriteActor = { id: number; authVersion: number };
export class SalesWriteError extends Error {
    constructor(message: string, public status = 400) { super(message); }
}

/** Call after the shop mutation lock; retained row locks protect the decision. */
export async function requireSalesWriteAuthority(manager: EntityManager, shopId: number, actor: SalesWriteActor) {
    if (!manager.queryRunner?.isTransactionActive) throw new Error('Sales authority requires an active transaction');
    if (!Number.isSafeInteger(shopId) || shopId <= 0 || !actor || !Number.isSafeInteger(actor.id) || actor.id <= 0 || !Number.isSafeInteger(actor.authVersion) || actor.authVersion < 0) throw new SalesWriteError('Phiên làm việc không hợp lệ', 401);
    const [user] = await manager.query('SELECT id,is_active,auth_version FROM users WHERE id=$1 FOR SHARE', [actor.id]);
    if (!user?.is_active || Number(user.auth_version) !== actor.authVersion) throw new SalesWriteError('Phiên làm việc đã hết hiệu lực', 401);
    await manager.query('SELECT id FROM shop_members WHERE shop_id=$1 AND user_id=$2 FOR SHARE', [shopId, actor.id]);
    let member = await manager.findOne(ShopMember, { where: { shopId, userId: actor.id, isActive: true, status: 'ACTIVE' }, relations: ['role'] });
    if (member?.roleId && member.memberType !== 'OWNER') {
        await manager.query('SELECT id FROM shop_roles WHERE id=$1 AND shop_id=$2 FOR SHARE', [member.roleId, shopId]);
        member = await manager.findOne(ShopMember, { where: { id: member.id, shopId, isActive: true, status: 'ACTIVE' }, relations: ['role'] });
    }
    if (!member || !membershipHasAnyPermission(member, ['sales'], 'edit', shopId)) throw new SalesWriteError('Bạn không còn quyền ghi nhận nghiệp vụ đơn hàng trong cửa hàng này', 403);
    return member;
}

export async function requireOpenSalesDay(manager: EntityManager, shopId: number, date: Date, memberType: string) {
    const day = vietnamDateKey(date);
    if (memberType !== 'OWNER' && await manager.exists(DailyClosing, { where: { shopId, closingDate: day as any } })) throw new SalesWriteError(`Ngày ${day} đã chốt sổ; cần OWNER xử lý điều chỉnh`, 403);
}
