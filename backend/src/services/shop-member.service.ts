import { In } from 'typeorm';
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

    /** List ACTIVE members of a shop */
    async findAll(shopId: number) {
        const members = await this.memberRepo.find({
            where: { shopId, status: 'ACTIVE' },
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

    /** List PENDING requests of a shop */
    async findAllPending(shopId: number | number[]) {
        const members = await this.memberRepo.find({
            where: { shopId: Array.isArray(shopId) ? In(shopId) : shopId, status: 'PENDING' },
            relations: ['shop'],
            order: { createdAt: 'ASC' },
        });
        const userIds = members.map(m => m.userId);
        const users = userIds.length ? await this.userRepo.findByIds(userIds) : [];
        const userMap = new Map(users.map(u => [u.id, u]));

        return members.map(m => {
            const u = userMap.get(m.userId);
            return {
                id: m.id,
                userId: m.userId,
                username: u?.username,
                fullName: u?.fullName,
                avatarUrl: u?.avatarUrl,
                status: m.status,
                createdAt: m.createdAt,
                shopId: m.shopId,
                shopName: m.shop?.shopName,
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
            status: 'ACTIVE',
            isActive: true,
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

    /** Search shops by code or name */
    async searchShops(query: string) {
        if (!query || query.length < 2) return [];
        return this.shopRepo.createQueryBuilder('s')
            .select(['s.id', 's.shopName', 's.shopCode', 's.businessSector'])
            .where('LOWER(s.shopName) LIKE LOWER(:q) OR LOWER(s.shopCode) LIKE LOWER(:q)', { q: `%${query}%` })
            .limit(10)
            .getMany();
    }

    /** Employee requests to join a shop */
    async requestJoin(userId: number, shopId: number) {
        // 1. Check if user is already a member or pending in ANY shop
        const existingAnywhere = await this.memberRepo.findOne({
            where: { userId }
        });
        if (existingAnywhere) {
            if (existingAnywhere.status === 'PENDING') {
                throw new Error('Bạn đã gửi yêu cầu gia nhập một cửa hàng khác và đang chờ duyệt.');
            }
            if (existingAnywhere.isActive) {
                throw new Error('Bạn đã là nhân viên của một cửa hàng. Mỗi nhân viên chỉ thuộc 1 cửa hàng.');
            }
        }

        const shop = await this.shopRepo.findOne({ where: { id: shopId } });
        if (!shop) throw new Error('Cửa hàng không tồn tại');

        // Create pending request
        const member = this.memberRepo.create({
            shopId,
            userId,
            memberType: 'EMPLOYEE',
            status: 'PENDING',
            isActive: false,
        });
        const saved = await this.memberRepo.save(member);

        // Notify OWNER(s) of this shop
        const owners = await this.memberRepo.find({ where: { shopId, memberType: 'OWNER', isActive: true } });
        const user = await this.userRepo.findOne({ where: { id: userId } });
        
        for (const owner of owners) {
            const notif = this.notifRepo.create({
                userId: owner.userId,
                type: 'JOIN_REQUEST',
                title: 'Yêu cầu gia nhập cửa hàng',
                message: `Tài khoản ${user?.fullName || user?.username} xin gia nhập cửa hàng.`,
                data: JSON.stringify({ shopId, memberId: saved.id, userId }),
            });
            await this.notifRepo.save(notif);
        }

        return saved;
    }

    /** Change a member's role */
    async updateRole(shopId: number, memberId: number, roleId: number) {
        const member = await this.memberRepo.findOneByOrFail({ id: memberId, shopId });
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
    async remove(shopId: number, memberId: number) {
        const member = await this.memberRepo.findOneByOrFail({ id: memberId, shopId });
        if (member.memberType === 'OWNER') throw new Error('Không thể xóa chủ shop');
        member.status = 'INACTIVE';
        member.isActive = false;
        await this.memberRepo.save(member);
        return { deleted: true };
    }

    /** Approve a join request */
    async approve(shopId: number, memberId: number) {
        const member = await this.memberRepo.findOneByOrFail({ id: memberId, shopId });
        if (member.status !== 'PENDING') throw new Error('Yêu cầu không còn ở trạng thái chờ duyệt');
        member.status = 'ACTIVE';
        member.isActive = true;
        const saved = await this.memberRepo.save(member);

        const shop = await this.shopRepo.findOne({ where: { id: member.shopId } });
        const notif = this.notifRepo.create({
            userId: member.userId,
            type: 'REQUEST_APPROVED',
            title: 'Yêu cầu được phê duyệt',
            message: `Yêu cầu tham gia cửa hàng "${shop?.shopName}" của bạn đã được phê duyệt.`,
            data: JSON.stringify({ shopId: member.shopId }),
        });
        await this.notifRepo.save(notif);
        return saved;
    }

    /** Reject a join request */
    async reject(shopId: number, memberId: number) {
        const member = await this.memberRepo.findOneByOrFail({ id: memberId, shopId });
        if (member.status !== 'PENDING') throw new Error('Yêu cầu không còn ở trạng thái chờ duyệt');
        member.status = 'REJECTED';
        member.isActive = false;
        const saved = await this.memberRepo.save(member);
        return saved;
    }

    /** Get all shops a user belongs to (for shop switching) */
    async getUserShops(userId: number) {
        const members = await this.memberRepo.find({
            where: { userId }, // include all so frontend knows about pending
            relations: ['role'],
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
            } else if (m.status === 'ACTIVE' && m.role?.permissions) {
                try { permissions = JSON.parse(m.role.permissions); } catch {}
            }
            return {
                shopId: m.shopId,
                shopName: shop?.shopName,
                shopCode: shop?.shopCode,
                memberType: m.memberType,
                status: m.status,
                role: m.role ? { id: m.role.id, name: m.role.name } : null,
                permissions,
            };
        });
    }
}
