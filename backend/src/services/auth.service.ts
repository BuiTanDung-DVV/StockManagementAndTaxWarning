import { AppDataSource } from '../config/db.config';
import { User } from '../auth/entities';
import { ShopMember } from '../shop/entities';
import * as jwt from 'jsonwebtoken';
import * as bcrypt from 'bcrypt';
import { config } from '../config/env.config';

export class AuthService {
    private userRepo = AppDataSource.getRepository(User);
    private memberRepo = AppDataSource.getRepository(ShopMember);

    async register(dto: Partial<User>) {
        const existing = await this.userRepo.findOne({ where: { username: dto.username } });
        if (existing) throw new Error('Username already exists');
        const password = (dto as any)?.password || (dto as any)?.passwordHash;
        if (!password) throw new Error('Missing password');

        const user = this.userRepo.create({
            ...dto,
            // Do not persist raw password
            passwordHash: await bcrypt.hash(password, 10),
        } as any);
        return this.userRepo.save(user);
    }

    async login(dto: any) {
        const user = await this.userRepo.findOne({ where: { username: dto.username } });
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

        // Fetch user's shop memberships with role info
        const memberships = await this.memberRepo.find({
            where: { userId: user.id, isActive: true },
            relations: ['role'],
        });
        const shops = memberships.map(m => {
            let permissions: Record<string, string> = {};
            if (m.memberType === 'OWNER') {
                permissions = { _owner: 'true' };
            } else if (m.role?.permissions) {
                try { permissions = JSON.parse(m.role.permissions); } catch {}
            }
            return {
                shopId: m.shopId,
                memberType: m.memberType,
                role: m.role ? { id: m.role.id, name: m.role.name } : null,
                permissions,
            };
        });

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
            },
            shops,
        };
    }

    /**
     * Simplified forgot-password for local/dev testing.
     * Accepts { identifier } (username/phone/email) and returns a reset hint.
     * In production this should send OTP/email; currently we only verify the user exists.
     */
    async forgotPassword(dto: any) {
        const identifier = (dto?.identifier || '').toString().trim();
        if (!identifier) throw new Error('Missing identifier');

        const user = await this.userRepo.findOne({ where: { username: identifier } });
        if (!user) {
            // Do not reveal whether account exists; still return success.
            return { sent: true };
        }

        return { sent: true, userId: user.id };
    }

    /**
     * Simplified reset-password for local/dev testing.
     * Accepts { identifier, newPassword }.
     */
    async resetPassword(dto: any) {
        const identifier = (dto?.identifier || '').toString().trim();
        const newPassword = (dto?.newPassword || '').toString();
        if (!identifier || !newPassword) throw new Error('Missing identifier or newPassword');

        const user = await this.userRepo.findOne({ where: { username: identifier } });
        if (!user) throw new Error('User not found');

        user.passwordHash = await bcrypt.hash(newPassword, 10);
        await this.userRepo.save(user);
        return { updated: true };
    }
}
