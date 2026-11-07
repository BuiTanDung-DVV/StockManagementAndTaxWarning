import { createHmac, randomInt, timingSafeEqual } from 'node:crypto';
import * as bcrypt from 'bcrypt';
import { DataSource, EntityManager } from 'typeorm';
import { AuthError } from '../auth/auth.errors';
import { User } from '../auth/entities';
import { normalizeEmail, sendOtpSchema } from '../auth/auth.schemas';
import { AppDataSource } from '../config/db.config';
import { config } from '../config/env.config';
import { EmailService } from './email.service';

const PURPOSE = 'VERIFY_EMAIL';
const MAX_ATTEMPTS = 5;
const RESEND_SECONDS = 60;

export interface ProfileVerificationActor {
    id: number;
    authVersion: number;
}

/** Verifies the current address only. Does not change email or Google bindings. */
export class ProfileEmailVerificationService {
    constructor(
        private readonly db: DataSource = AppDataSource,
        private readonly mail: Pick<EmailService, 'sendOtp'> = new EmailService(),
    ) {}

    private hash(value: string): string {
        return createHmac('sha256', config.otpSecret).update(value).digest('hex');
    }

    private identifier(user: User, email: string): string {
        return `profile-email:${this.hash(JSON.stringify([user.id, user.authVersion, email]))}`;
    }

    private codeHash(identifier: string, code: string): string {
        return this.hash(`${PURPOSE}:${identifier}:${code}`);
    }

    private async currentUser(manager: EntityManager, actor: ProfileVerificationActor, expectedEmail: string): Promise<User> {
        if (!Number.isSafeInteger(actor.id) || actor.id <= 0
            || !Number.isSafeInteger(actor.authVersion) || actor.authVersion < 0) {
            throw new AuthError('Vui lòng đăng nhập lại', 401, 'SESSION_INVALID');
        }
        const repository = manager.getRepository(User);
        const snapshot = await repository.findOne({ where: { id: actor.id } });
        if (!snapshot || !snapshot.isActive || snapshot.authVersion !== actor.authVersion) {
            throw new AuthError('Vui lòng đăng nhập lại', 401, 'SESSION_INVALID');
        }
        if (!snapshot.email) throw new AuthError('Tài khoản chưa có Gmail', 400, 'EMAIL_MISSING');
        const address = normalizeEmail(snapshot.email);
        if (address !== normalizeEmail(expectedEmail)) {
            throw new AuthError('Gmail đã thay đổi. Vui lòng tải lại hồ sơ', 409, 'EMAIL_CHANGED');
        }
        // Same email lock as register/Google; lock order is email, then user.
        await manager.query('SELECT pg_advisory_xact_lock(hashtext($1))', [address]);
        const user = await repository.findOne({
            where: { id: actor.id }, lock: { mode: 'pessimistic_write' },
        });
        if (!user || !user.isActive || user.authVersion !== actor.authVersion) {
            throw new AuthError('Vui lòng đăng nhập lại', 401, 'SESSION_INVALID');
        }
        if (normalizeEmail(user.email || '') !== address) {
            throw new AuthError('Gmail đã thay đổi. Vui lòng tải lại hồ sơ', 409, 'EMAIL_CHANGED');
        }
        if (user.lockedUntil && user.lockedUntil.getTime() > Date.now()) {
            throw new AuthError('Tài khoản tạm khóa. Vui lòng thử lại sau', 429, 'ACCOUNT_LOCKED');
        }
        if (!sendOtpSchema.shape.identifier.safeParse(address).success) {
            throw new AuthError('Gmail trong hồ sơ không hợp lệ', 400, 'EMAIL_INVALID');
        }
        const other = await repository.createQueryBuilder('other')
            .where('(LOWER(other.email) = :email OR LOWER(other.username) = :email)', { email: address })
            .andWhere('other.id <> :id', { id: actor.id }).getOne();
        if (other) {
            throw new AuthError('Gmail trùng với tài khoản khác. Vui lòng liên hệ hỗ trợ', 409, 'EMAIL_CONFLICT');
        }
        return user;
    }

    async request(actor: ProfileVerificationActor, currentPassword: string, expectedEmail: string) {
        const result = await this.db.transaction(async manager => {
            const user = await this.currentUser(manager, actor, expectedEmail);
            const email = normalizeEmail(user.email);
            if (user.emailVerified) return { kind: 'verified' as const, email };
            if (!user.passwordHash) {
                if (user.googleSubject) {
                    throw new AuthError('Vui lòng đăng nhập lại bằng Google để xác minh Gmail', 400, 'GOOGLE_REAUTH_REQUIRED');
                }
                throw new AuthError('Tài khoản chưa có phương thức xác thực lại. Vui lòng liên hệ hỗ trợ', 400, 'REAUTH_UNAVAILABLE');
            }
            if (!await bcrypt.compare(currentPassword, user.passwordHash)) {
                user.failedLoginAttempts += 1;
                if (user.failedLoginAttempts >= MAX_ATTEMPTS) {
                    user.lockedUntil = new Date(Date.now() + 15 * 60_000);
                    user.failedLoginAttempts = 0;
                }
                await manager.getRepository(User).save(user);
                // Return, then throw after commit so failure accounting persists.
                return { kind: 'error' as const, error: new AuthError('Mật khẩu hiện tại không đúng', 401, 'INVALID_CREDENTIALS') };
            }
            const identifier = this.identifier(user, email);
            const [recent] = await manager.query(
                `SELECT COUNT(*)::int AS count,
                    COALESCE(BOOL_OR(created_at > NOW() - INTERVAL '60 seconds'), false) AS cooldown
                 FROM otps WHERE phone = $1 AND purpose = $2
                    AND created_at > NOW() - INTERVAL '15 minutes'`, [identifier, PURPOSE]);
            if (Number(recent.count) >= 3 || recent.cooldown) {
                throw new AuthError('Chưa thể gửi lại mã. Vui lòng chờ rồi thử lại', 429, 'OTP_RATE_LIMIT');
            }
            await manager.query(
                'UPDATE otps SET consumed_at = NOW() WHERE phone = $1 AND purpose = $2 AND consumed_at IS NULL',
                [identifier, PURPOSE]);
            const code = randomInt(100000, 1000000).toString();
            const [challenge] = await manager.query(
                `INSERT INTO otps(phone, otp_code, purpose, attempts, expires_at)
                 VALUES ($1, $2, $3, 0, NOW() + INTERVAL '5 minutes') RETURNING id`,
                [identifier, this.codeHash(identifier, code), PURPOSE]);
            user.failedLoginAttempts = 0;
            user.lockedUntil = null;
            await manager.getRepository(User).save(user);
            return { kind: 'challenge' as const, email, code, id: challenge.id };
        });
        if (result.kind === 'error') throw result.error;
        if (result.kind === 'verified') return { email: result.email, emailVerified: true };
        let sent = false;
        try {
            sent = await this.mail.sendOtp(result.email, result.code, 'PROFILE_EMAIL');
        } catch { /* Do not expose SMTP details or return the code. */ }
        if (!sent) {
            // Keep failed deliveries in the send limit; never invalidate a newer request.
            await this.db.query('UPDATE otps SET consumed_at = NOW() WHERE id = $1', [result.id]);
            throw new AuthError('Không thể gửi mã xác minh. Vui lòng thử lại sau', 503, 'OTP_DELIVERY_FAILED');
        }
        return { email: result.email, emailVerified: false, resendAfterSeconds: RESEND_SECONDS, expiresInSeconds: 300 };
    }

    async confirm(actor: ProfileVerificationActor, code: string, expectedEmail: string) {
        const result = await this.db.transaction(async manager => {
            const user = await this.currentUser(manager, actor, expectedEmail);
            if (user.emailVerified) {
                throw new AuthError('Gmail đã được xác minh. Vui lòng tải lại hồ sơ', 409, 'EMAIL_ALREADY_VERIFIED');
            }
            const email = normalizeEmail(user.email);
            const identifier = this.identifier(user, email);
            const [challenge] = await manager.query(
                `SELECT id, otp_code, attempts FROM otps
                 WHERE phone = $1 AND purpose = $2 AND consumed_at IS NULL AND expires_at > NOW()
                 ORDER BY created_at DESC, id DESC LIMIT 1 FOR UPDATE`, [identifier, PURPOSE]);
            if (!challenge) return { error: new AuthError('Mã xác minh không đúng hoặc đã hết hạn', 400, 'OTP_INVALID') };
            if (Number(challenge.attempts) >= MAX_ATTEMPTS) {
                return { error: new AuthError('Mã xác minh đã bị khóa. Vui lòng yêu cầu mã mới', 429, 'OTP_LOCKED') };
            }
            const expected = Buffer.from(this.codeHash(identifier, code), 'hex');
            const stored = Buffer.from(String(challenge.otp_code), 'hex');
            if (stored.length !== expected.length || !timingSafeEqual(stored, expected)) {
                await manager.query('UPDATE otps SET attempts = attempts + 1 WHERE id = $1', [challenge.id]);
                return { error: new AuthError('Mã xác minh không đúng hoặc đã hết hạn', 400, 'OTP_INVALID') };
            }
            await manager.query('UPDATE otps SET consumed_at = NOW() WHERE id = $1', [challenge.id]);
            user.emailVerified = true;
            await manager.getRepository(User).save(user);
            return { email, emailVerified: true as const };
        });
        if ('error' in result) throw result.error;
        return result;
    }
}
