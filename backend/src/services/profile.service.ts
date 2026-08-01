import { RefreshSession, User } from '../auth/entities';
import { AppDataSource } from '../config/db.config';

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
            emailVerified: user.emailVerified,
            phone: user.phone || null,
            avatarUrl: user.avatarUrl || null,
            accountType: user.accountType,
            isOnboarded: user.isOnboarded,
            role: user.role,
            createdAt: user.createdAt,
        };
    }

    async updateProfile(
        userId: number,
        dto: { fullName?: string; phone?: string; avatarUrl?: string },
    ) {
        const user = await this.userRepo.findOne({ where: { id: userId } });
        if (!user) throw new Error('User not found');
        if (dto.fullName !== undefined) user.fullName = dto.fullName;
        if (dto.phone !== undefined) user.phone = dto.phone;
        if (dto.avatarUrl !== undefined) user.avatarUrl = dto.avatarUrl;
        await this.userRepo.save(user);
        return {
            id: user.id,
            username: user.username,
            fullName: user.fullName,
            email: user.email || null,
            emailVerified: user.emailVerified,
            phone: user.phone || null,
            avatarUrl: user.avatarUrl || null,
            accountType: user.accountType,
            isOnboarded: user.isOnboarded,
        };
    }

    async changePassword(
        userId: number,
        dto: { currentPassword: string; newPassword: string },
    ) {
        const bcrypt = await import('bcrypt');
        await AppDataSource.transaction(async manager => {
            const repository = manager.getRepository(User);
            const user = await repository.findOne({ where: { id: userId } });
            if (!user) throw new Error('User not found');
            const valid = await bcrypt.compare(dto.currentPassword, user.passwordHash || '');
            if (!valid) throw new Error('Mật khẩu hiện tại không đúng');
            user.passwordHash = await bcrypt.hash(dto.newPassword, 12);
            user.authVersion += 1;
            await repository.save(user);
            await manager.getRepository(RefreshSession)
                .createQueryBuilder()
                .update()
                .set({ revokedAt: new Date() })
                .where('user_id = :userId AND revoked_at IS NULL', { userId })
                .execute();
        });
        return { updated: true };
    }
}
