import { AppDataSource } from '../config/db.config';
import { User } from '../auth/entities';

export class ProfileService {
    private userRepo = AppDataSource.getRepository(User);

    async getProfile(userId: number) {
        const user = await this.userRepo.findOne({ where: { id: userId } });
        if (!user) throw new Error('User not found');
        return {
            id: user.id,
            username: user.username,
            fullName: user.fullName,
            email: user.email || null,
            phone: user.phone || null,
            avatarUrl: user.avatarUrl || null,
            accountType: user.accountType,
            role: user.role,
            createdAt: user.createdAt,
        };
    }

    async updateProfile(userId: number, dto: { fullName?: string; email?: string; phone?: string; avatarUrl?: string }) {
        const user = await this.userRepo.findOne({ where: { id: userId } });
        if (!user) throw new Error('User not found');

        if (dto.fullName !== undefined) user.fullName = dto.fullName;
        if (dto.email !== undefined) user.email = dto.email;
        if (dto.phone !== undefined) user.phone = dto.phone;
        if (dto.avatarUrl !== undefined) user.avatarUrl = dto.avatarUrl;

        await this.userRepo.save(user);
        return {
            id: user.id,
            username: user.username,
            fullName: user.fullName,
            email: user.email || null,
            phone: user.phone || null,
            avatarUrl: user.avatarUrl || null,
            accountType: user.accountType,
        };
    }

    async changePassword(userId: number, dto: { currentPassword: string; newPassword: string }) {
        const bcrypt = await import('bcrypt');
        const user = await this.userRepo.findOne({ where: { id: userId } });
        if (!user) throw new Error('User not found');

        const valid = await bcrypt.compare(dto.currentPassword, user.passwordHash || '');
        if (!valid) throw new Error('Mật khẩu hiện tại không đúng');

        user.passwordHash = await bcrypt.hash(dto.newPassword, 10);
        await this.userRepo.save(user);
        return { updated: true };
    }
}
