import { AppDataSource } from '../config/db.config';
import { User } from '../auth/entities';
import { ShopMember } from '../shop/entities';
import { ShopProfile } from '../system/entities';
import { ILike } from 'typeorm';
import * as jwt from 'jsonwebtoken';
import * as bcrypt from 'bcrypt';
import { config } from '../config/env.config';

export class AuthService {
    private userRepo = AppDataSource.getRepository(User);
    private memberRepo = AppDataSource.getRepository(ShopMember);
    private shopRepo = AppDataSource.getRepository(ShopProfile);

    async register(dto: Partial<User>) {
        const identifier = (dto.username || '').toString().trim();
        const isPhone = /^(0|\+84)\d{8,9}$/.test(identifier);

        if (isPhone) {
            dto.phone = identifier;
        }
        (dto as any).isOnboarded = false;

        const existing = await this.userRepo.findOne({
            where: [
                { username: identifier },
                ...(isPhone ? [{ phone: identifier }] : [])
            ]
        });
        if (existing) throw new Error('Username or phone already exists');
        
        const password = (dto as any)?.password || (dto as any)?.passwordHash;
        if (!password) throw new Error('Missing password');

        const user = this.userRepo.create({
            ...dto,
            username: identifier,
            // Do not persist raw password
            passwordHash: await bcrypt.hash(password, 10),
        } as any);
        return this.userRepo.save(user);
    }

    async login(dto: any) {
        const identifier = (dto.username || '').toString().trim();
        const user = await this.userRepo.findOne({
            where: [
                { username: identifier },
                { phone: identifier }
            ]
        });
        const password = (dto?.password || '').toString();
        if (!user || !(await bcrypt.compare(password, user.passwordHash || ''))) {
            throw new Error('Invalid credentials');
        }
        if (!user.isActive) {
            throw new Error('Account is inactive');
        }

        const payload = { sub: user.id, username: user.username, role: user.role, accountType: user.accountType };
        const accessToken = jwt.sign(
            payload,
            config.jwtSecret as jwt.Secret,
            { expiresIn: String(config.jwtExpiresIn) } as jwt.SignOptions,
        );

        let shops: any[] = [];
        try {
            const memberships = await this.memberRepo.find({
                where: { userId: user.id }, // Get all to check PENDING status
                relations: ['role'],
            });
            shops = memberships.map(m => {
                let permissions: Record<string, string> = {};
                if (m.memberType === 'OWNER') {
                    permissions = { _owner: 'true' };
                } else if (m.status === 'ACTIVE' && m.role?.permissions) {
                    try {
                        permissions = JSON.parse(m.role.permissions);
                    } catch {
                        permissions = {};
                    }
                }
                return {
                    shopId: m.shopId,
                    memberType: m.memberType,
                    status: m.status,
                    role: m.role ? { id: m.role.id, name: m.role.name } : null,
                    permissions,
                };
            });
        } catch (e: any) {
            shops = [];
        }

        return {
            access_token: accessToken,
            user: {
                id: user.id,
                username: user.username,
                role: user.role,
                fullName: user.fullName,
                email: user.email || null,
                phone: user.phone || null,
                avatarUrl: user.avatarUrl || null,
                accountType: user.accountType,
                isOnboarded: user.isOnboarded,
            },
            shops,
        };
    }

    async forgotPassword(dto: any) {
        const identifier = (dto?.identifier || '').toString().trim();
        if (!identifier) throw new Error('Missing identifier');

        const user = await this.userRepo.findOne({
            where: [
                { username: identifier },
                { phone: identifier }
            ]
        });
        if (!user) {
            // Do not reveal whether account exists; still return success.
            return { sent: true };
        }

        return { sent: true, userId: user.id };
    }

    async resetPassword(dto: any) {
        const identifier = (dto?.identifier || '').toString().trim();
        const newPassword = (dto?.newPassword || '').toString();
        if (!identifier || !newPassword) throw new Error('Missing identifier or newPassword');

        const user = await this.userRepo.findOne({
            where: [
                { username: identifier },
                { phone: identifier }
            ]
        });
        if (!user) throw new Error('User not found');

        user.passwordHash = await bcrypt.hash(newPassword, 10);
        await this.userRepo.save(user);
        return { updated: true };
    }

    async searchShops(q: string) {
        if (!q || q.trim().length === 0) return [];
        const shops = await this.shopRepo.find({
            where: { shopName: ILike(`%${q.trim()}%`) },
            take: 10,
            select: ['id', 'shopName', 'address', 'logoUrl'] // DO NOT expose shopCode
        });
        return shops;
    }

    async completeOnboarding(userId: number, dto: any) {
        const user = await this.userRepo.findOne({ where: { id: userId } });
        if (!user) throw new Error('User not found');

        if (dto.username) {
            const newUsername = dto.username.toString().trim();
            const existing = await this.userRepo.findOne({ where: { username: newUsername } });
            if (existing && existing.id !== user.id) throw new Error('Username already exists');
            user.username = newUsername;
        }

        if (dto.phone) {
            const newPhone = dto.phone.toString().trim();
            const existing = await this.userRepo.findOne({ where: { phone: newPhone } });
            if (existing && existing.id !== user.id) throw new Error('Phone already exists');
            user.phone = newPhone;
        }

        if (dto.fullName) user.fullName = dto.fullName.toString().trim();
        user.isOnboarded = true;
        // Business logic parsing
        let status = 'ACTIVE';

        await AppDataSource.transaction(async manager => {
            await manager.save(user);

            if (user.accountType === 'SHOP') {
                // Generate a random 6-char shopCode (e.g. A-Z0-9)
                const charSet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
                let code = '';
                for (let i = 0; i < 6; i++) {
                    code += charSet.charAt(Math.floor(Math.random() * charSet.length));
                }

                const shopName = dto.shopName?.toString().trim() || user.fullName;
                const ownerName = dto.ownerName?.toString().trim() || user.fullName;

                const shop = manager.create(ShopProfile, {
                    shopName: shopName,
                    ownerName: ownerName,
                    address: dto.address?.toString().trim() || '',
                    shopCode: code,
                });
                const savedShop = await manager.save(shop);

                const member = manager.create(ShopMember, {
                    shopId: savedShop.id,
                    userId: user.id,
                    memberType: 'OWNER',
                    status: 'ACTIVE',
                    isActive: true, // Keep backward compatible flag
                });
                await manager.save(member);
            } 
            else if (user.accountType === 'PERSONAL') {
                status = 'PENDING';
                const submittedShopCode = dto.shopCode?.toString().trim();
                const submittedShopId = dto.shopId ? parseInt(dto.shopId, 10) : null;

                if (!submittedShopCode) throw new Error('Yêu cầu bắt buộc phải có mã cửa hàng.');

                const whereClause: any = { shopCode: submittedShopCode };
                if (submittedShopId) whereClause.id = submittedShopId;

                const targetShop = await manager.findOne(ShopProfile, { where: whereClause });
                if (!targetShop) throw new Error('Không tìm thấy Cửa hàng khớp với yêu cầu của bạn.');

                const member = manager.create(ShopMember, {
                    shopId: targetShop.id,
                    userId: user.id,
                    memberType: 'EMPLOYEE',
                    status: 'PENDING',
                    isActive: true, // They technically exist, but status blocks features
                });
                await manager.save(member);
            }
        });

        return { 
            updated: true, 
            status: status, // PENDING for personal, ACTIVE for shop. App controls routing.
            user: { 
                id: user.id, username: user.username, phone: user.phone, 
                fullName: user.fullName, isOnboarded: user.isOnboarded, accountType: user.accountType 
            } 
        };
    }
}
