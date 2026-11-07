import { RefreshSession, User } from '../auth/entities';
import { AppDataSource } from '../config/db.config';
import { AuthError } from '../auth/auth.errors';

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
            hasPassword: Boolean(user.passwordHash),
            googleLinked: Boolean(user.googleSubject),
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
        authVersion: number,
    ) {
        const updates: Partial<User> = {};
        if (dto.fullName !== undefined) updates.fullName = dto.fullName;
        if (dto.phone !== undefined) updates.phone = dto.phone;
        if (dto.avatarUrl !== undefined) updates.avatarUrl = dto.avatarUrl;
        if (!Number.isSafeInteger(authVersion) || authVersion < 0) throw new AuthError('Vui lòng đăng nhập lại',401,'SESSION_INVALID');
        if (Object.keys(updates).length) {
            const result = await this.userRepo.update({id:userId,authVersion,isActive:true},updates);
            if (!result.affected) throw new AuthError('Phiên đăng nhập đã thay đổi. Vui lòng đăng nhập lại',401,'SESSION_INVALID');
        } else if (!await this.userRepo.findOneBy({id:userId,authVersion,isActive:true})) {
            throw new AuthError('Vui lòng đăng nhập lại',401,'SESSION_INVALID');
        }
        return this.getProfile(userId);
    }

    async changePassword(
        userId: number,
        dto: { currentPassword: string; newPassword: string },
        authVersion: number,
    ) {
        const bcrypt = await import('bcrypt');
        await AppDataSource.transaction(async manager => {
            const repository = manager.getRepository(User);
            const user = await repository.findOne({ where: { id: userId,authVersion,isActive:true } });
            if (!user) throw new AuthError('Vui lòng đăng nhập lại',401,'SESSION_INVALID');
            const valid = await bcrypt.compare(dto.currentPassword, user.passwordHash || '');
            if (!valid) throw new Error('Mật khẩu hiện tại không đúng');
            const result=await repository.update({id:userId,authVersion,isActive:true}, {
                passwordHash:await bcrypt.hash(dto.newPassword,12),authVersion:authVersion+1,
            });
            if (!result.affected) throw new AuthError('Phiên đăng nhập đã thay đổi. Vui lòng đăng nhập lại',401,'SESSION_INVALID');
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
