import { AppDataSource } from '../config/db.config';
import { ShopMember, ShopRole, Notification } from '../shop/entities';
import { User } from '../auth/entities';
import { ShopProfile } from '../system/entities';

export class ShopMemberService {
    private memberRepo = AppDataSource.getRepository(ShopMember);
    private userRepo = AppDataSource.getRepository(User);
    private shopRepo = AppDataSource.getRepository(ShopProfile);
    private notifRepo = AppDataSource.getRepository(Notification);
    private roleRepo = AppDataSource.getRepository(ShopRole);

    /** List members of a shop */
    async findAll(shopId: number) {
        const members = await this.memberRepo.find({
            where: { shopId },
            order: { memberType: 'ASC', createdAt: 'ASC' },
        });
        // Attach user info
        const userIds = members.map(m => m.userId);
        const users = userIds.length
            ? await this.userRepo.findByIds(userIds)
            : [];
        const userMap = new Map(users.map(u => [u.id, u]));

        return members.map(m => {
            const u = userMap.get(m.userId);
            return {
                id: m.id,
                userId: m.userId,
                username: u?.username,
                fullName: u?.fullName,
                memberType: m.memberType,
                role: m.role ? { id: m.role.id, name: m.role.name } : null,
                isActive: m.isActive,
                createdAt: m.createdAt,
            };
        });
    }

    /** Invite a user by username */
    async invite(shopId: number, username: string, roleId?: number) {
        const user = await this.userRepo.findOne({ where: { username } });
        if (!user) throw new Error('Không tìm thấy tài khoản với username này');

        const existing = await this.memberRepo.findOne({ where: { shopId, userId: user.id } });
        if (existing) throw new Error('Người dùng đã là thành viên của shop');

        const member = this.memberRepo.create({
            shopId,
            userId: user.id,
            roleId: roleId || undefined,
            memberType: 'EMPLOYEE',
        });
        const saved = await this.memberRepo.save(member);

        // Get shop name for notification
        const shop = await this.shopRepo.findOne({ where: { id: shopId } });
        const roleName = roleId
            ? (await this.roleRepo.findOne({ where: { id: roleId } }))?.name || 'Nhân viên'
            : 'Nhân viên';

        // Send notification to the invited user
        const notif = this.notifRepo.create({
            userId: user.id,
            type: 'SHOP_INVITE',
            title: 'Được thêm vào cửa hàng',
            message: `Bạn đã được thêm vào "${shop?.shopName}" với vai trò "${roleName}"`,
            data: JSON.stringify({ shopId, shopName: shop?.shopName, memberType: 'EMPLOYEE', roleId }),
        });
        await this.notifRepo.save(notif);

        return saved;
    }

    /** Change a member's role */
    async updateRole(memberId: number, roleId: number) {
        const member = await this.memberRepo.findOneByOrFail({ id: memberId });
        member.roleId = roleId;
        const saved = await this.memberRepo.save(member);

        // Notify user of role change
        const role = await this.roleRepo.findOne({ where: { id: roleId } });
        const shop = await this.shopRepo.findOne({ where: { id: member.shopId } });
        const notif = this.notifRepo.create({
            userId: member.userId,
            type: 'ROLE_CHANGE',
            title: 'Thay đổi vai trò',
            message: `Vai trò của bạn tại "${shop?.shopName}" đã đổi thành "${role?.name}"`,
            data: JSON.stringify({ shopId: member.shopId, roleId }),
        });
        await this.notifRepo.save(notif);

        return saved;
    }

    /** Remove a member from shop */
    async remove(memberId: number) {
        const member = await this.memberRepo.findOneByOrFail({ id: memberId });
        if (member.memberType === 'OWNER') throw new Error('Không thể xóa chủ shop');
        await this.memberRepo.delete(memberId);
        return { deleted: true };
    }

    /** Get all shops a user belongs to (for shop switching) */
    async getUserShops(userId: number) {
        const members = await this.memberRepo.find({
            where: { userId, isActive: true },
        });
        const shopIds = members.map(m => m.shopId);
        const shops = shopIds.length
            ? await this.shopRepo.findByIds(shopIds)
            : [];
        const shopMap = new Map(shops.map(s => [s.id, s]));

        return members.map(m => {
            const shop = shopMap.get(m.shopId);
            // Parse permissions from role
            let permissions: Record<string, string> = {};
            if (m.memberType === 'OWNER') {
                permissions = { _owner: 'true' }; // special flag
            } else if (m.role?.permissions) {
                try { permissions = JSON.parse(m.role.permissions); } catch {}
            }
            return {
                shopId: m.shopId,
                shopName: shop?.shopName,
                memberType: m.memberType,
                role: m.role ? { id: m.role.id, name: m.role.name } : null,
                permissions,
            };
        });
    }
}
