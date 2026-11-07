import { createHmac, randomInt, randomUUID, timingSafeEqual } from 'node:crypto';
import * as bcrypt from 'bcrypt';
import * as jwt from 'jsonwebtoken';
import { OAuth2Client } from 'google-auth-library';
import { DataSource, EntityManager } from 'typeorm';
import { AuthError } from '../auth/auth.errors';
import { RefreshSession, User } from '../auth/entities';
import { ConfirmProfileEmailChangeDto, RequestProfileEmailChangeDto, normalizeEmail, sendOtpSchema } from '../auth/auth.schemas';
import { AppDataSource } from '../config/db.config';
import { config } from '../config/env.config';
import { EmailService } from './email.service';
import { ProfileVerificationActor } from './profile-email-verification.service';

const OLD = 'EMAIL_CHANGE_OLD';
const NEW = 'EMAIL_CHANGE_NEW';
const AUDIENCE = 'smartstock-email-change';
const ISSUER = 'SmartStock';

interface GoogleIdentity { sub: string; email: string }
interface Proposal {
    kind: 'EMAIL_CHANGE';
    userId: number;
    version: number;
    oldEmail: string;
    newEmail: string;
    oldGoogleSubject: string | null;
    newGoogleSubject: string | null;
    nonce: string;
}

export async function verifyProfileGoogleIdentity(idToken: string): Promise<GoogleIdentity> {
    if (!config.googleClientIds.length) throw new AuthError('Đăng nhập Google chưa được cấu hình', 503, 'GOOGLE_NOT_CONFIGURED');
    try {
        const ticket = await new OAuth2Client().verifyIdToken({ idToken, audience: config.googleClientIds });
        const payload = ticket.getPayload();
        const now = Math.floor(Date.now() / 1000);
        if (!payload?.sub || !payload.email_verified || !payload.email
            || !sendOtpSchema.shape.identifier.safeParse(payload.email).success
            || !payload.iat || payload.iat < now - 600 || payload.iat > now + 60) {
            throw new Error('Reauthentication is required');
        }
        return { sub: payload.sub, email: normalizeEmail(payload.email) };
    } catch {
        throw new AuthError('Vui lòng chọn và đăng nhập lại đúng tài khoản Google', 401, 'GOOGLE_REAUTH_INVALID');
    }
}

export class ProfileEmailChangeService {
    constructor(
        private readonly db: DataSource = AppDataSource,
        private readonly mail: Pick<EmailService, 'sendOtp' | 'sendEmailChanged'> = new EmailService(),
        private readonly verifyGoogle: (token: string) => Promise<GoogleIdentity> = verifyProfileGoogleIdentity,
    ) {}

    private hash(value: string): string {
        return createHmac('sha256', config.otpSecret).update(value).digest('hex');
    }

    private get proposalKey(): string { return this.hash('smartstock:email-change:proposal:v1'); }
    private identifier(userId: number, nonce = ''): string { return `email-change:${userId}:${nonce}`; }
    private codeHash(identifier: string, purpose: string, token: string, code: string): string {
        return this.hash(JSON.stringify([identifier, purpose, this.hash(token), code]));
    }

    private parseProposal(token: string, actor: ProfileVerificationActor): Proposal {
        try {
            const payload = jwt.verify(token, this.proposalKey, { algorithms: ['HS256'], audience: AUDIENCE, issuer: ISSUER }) as jwt.JwtPayload;
            if (payload.kind !== 'EMAIL_CHANGE' || payload.userId !== actor.id || payload.version !== actor.authVersion
                || !Number.isSafeInteger(payload.userId) || !Number.isSafeInteger(payload.version)
                || typeof payload.nonce !== 'string' || !/^[a-f0-9-]{36}$/.test(payload.nonce)
                || !sendOtpSchema.shape.identifier.safeParse(payload.oldEmail).success
                || !sendOtpSchema.shape.identifier.safeParse(payload.newEmail).success
                || payload.oldEmail === payload.newEmail
                || ![null, 'string'].includes(payload.oldGoogleSubject === null ? null : typeof payload.oldGoogleSubject)
                || ![null, 'string'].includes(payload.newGoogleSubject === null ? null : typeof payload.newGoogleSubject)
                || !payload.iat || !payload.exp || payload.exp - payload.iat > 300) throw new Error('Invalid proposal');
            return payload as unknown as Proposal;
        } catch {
            throw new AuthError('Yêu cầu đổi Gmail không hợp lệ hoặc đã hết hạn. Vui lòng thực hiện lại', 400, 'EMAIL_CHANGE_INVALID');
        }
    }

    private async lockedUser(manager: EntityManager, actor: ProfileVerificationActor, oldEmail: string, newEmail: string): Promise<User> {
        if (!Number.isSafeInteger(actor.id) || actor.id <= 0 || !Number.isSafeInteger(actor.authVersion) || actor.authVersion < 0) {
            throw new AuthError('Vui lòng đăng nhập lại', 401, 'SESSION_INVALID');
        }
        // Shared with register/Google/verification. Deterministic order avoids swaps deadlocking.
        for (const email of [...new Set([oldEmail, newEmail])].sort()) {
            await manager.query('SELECT pg_advisory_xact_lock(hashtext($1))', [email]);
        }
        const repository = manager.getRepository(User);
        const user = await repository.findOne({ where: { id: actor.id }, lock: { mode: 'pessimistic_write' } });
        if (!user || !user.isActive || user.authVersion !== actor.authVersion) {
            throw new AuthError('Vui lòng đăng nhập lại', 401, 'SESSION_INVALID');
        }
        if (user.lockedUntil && user.lockedUntil.getTime() > Date.now()) {
            throw new AuthError('Tài khoản tạm khóa. Vui lòng thử lại sau', 429, 'ACCOUNT_LOCKED');
        }
        if (normalizeEmail(user.email || '') !== oldEmail) {
            throw new AuthError('Gmail đã thay đổi. Vui lòng tải lại hồ sơ', 409, 'EMAIL_CHANGED');
        }
        if (!user.emailVerified) {
            throw new AuthError('Cần xác minh Gmail hiện tại trước khi đổi', 400, 'EMAIL_NOT_VERIFIED');
        }
        return user;
    }

    private async assertAvailable(manager: EntityManager, userId: number, newEmail: string, newSubject: string | null) {
        const other = await manager.getRepository(User).createQueryBuilder('other')
            .where('(LOWER(other.email) = :email OR LOWER(other.username) = :email OR other.googleSubject = :subject)',
                { email: newEmail, subject: newSubject })
            .andWhere('other.id <> :id', { id: userId }).getOne();
        if (other) throw new AuthError('Gmail hoặc tài khoản Google mới đã thuộc tài khoản khác', 409, 'EMAIL_EXISTS');
    }

    async request(actor: ProfileVerificationActor, dto: RequestProfileEmailChangeDto) {
        const oldEmail = normalizeEmail(dto.expectedEmail), newEmail = normalizeEmail(dto.newEmail);
        if (oldEmail === newEmail) throw new AuthError('Gmail mới phải khác Gmail hiện tại',400,'EMAIL_UNCHANGED');
        const currentGoogle = dto.currentGoogleIdToken ? await this.verifyGoogle(dto.currentGoogleIdToken) : null;
        const nextGoogle = dto.newGoogleIdToken ? await this.verifyGoogle(dto.newGoogleIdToken) : null;
        const result = await this.db.transaction(async manager => {
            const user = await this.lockedUser(manager, actor, oldEmail, newEmail);
            if (dto.currentPassword) {
                if (!user.passwordHash || !await bcrypt.compare(dto.currentPassword, user.passwordHash)) {
                    user.failedLoginAttempts += 1;
                    if (user.failedLoginAttempts >= 5) {
                        user.lockedUntil = new Date(Date.now() + 15 * 60_000); user.failedLoginAttempts = 0;
                    }
                    await manager.getRepository(User).save(user);
                    return { kind: 'error' as const, error: new AuthError('Mật khẩu hiện tại không đúng', 401, 'INVALID_CREDENTIALS') };
                }
            } else if (!user.googleSubject || currentGoogle?.sub !== user.googleSubject) {
                throw new AuthError('Cần đăng nhập lại tài khoản Google hiện đang liên kết', 401, 'GOOGLE_CURRENT_MISMATCH');
            }
            if (user.googleSubject && (!nextGoogle || nextGoogle.email !== newEmail)) {
                throw new AuthError('Cần đăng nhập Google bằng Gmail mới để chuyển liên kết', 400, 'GOOGLE_NEW_REQUIRED');
            }
            if (!user.googleSubject && nextGoogle) {
                throw new AuthError('Liên kết Google đã thay đổi. Vui lòng tải lại hồ sơ', 409, 'GOOGLE_LINK_CHANGED');
            }
            await this.assertAvailable(manager, user.id, newEmail, nextGoogle?.sub || null);
            const prefix = `${this.identifier(user.id)}%`;
            const [recent] = await manager.query(`SELECT COUNT(*)::int AS count,
                COALESCE(BOOL_OR(created_at > NOW() - INTERVAL '60 seconds'),false) AS cooldown
                FROM otps WHERE phone LIKE $1 AND purpose=$2 AND created_at > NOW()-INTERVAL '15 minutes'`, [prefix, OLD]);
            if (Number(recent.count) >= 3 || recent.cooldown) {
                throw new AuthError('Chưa thể gửi lại mã. Vui lòng chờ rồi thử lại', 429, 'OTP_RATE_LIMIT');
            }
            const proposal: Proposal = {kind:'EMAIL_CHANGE', userId:user.id, version:user.authVersion,
                oldEmail, newEmail, oldGoogleSubject:user.googleSubject || null,
                newGoogleSubject:nextGoogle?.sub || null, nonce:randomUUID()};
            const operationToken = jwt.sign(proposal, this.proposalKey, {algorithm:'HS256', issuer:ISSUER, audience:AUDIENCE, expiresIn:300});
            const identifier = this.identifier(user.id, proposal.nonce);
            await manager.query('UPDATE otps SET consumed_at=NOW() WHERE phone LIKE $1 AND purpose IN ($2,$3) AND consumed_at IS NULL', [prefix, OLD, NEW]);
            const deliveries = [{email:oldEmail, purpose:OLD, code:randomInt(100000,1000000).toString()}];
            if (!nextGoogle) deliveries.push({email:newEmail, purpose:NEW, code:randomInt(100000,1000000).toString()});
            const challengeIds: number[] = [];
            for (const delivery of deliveries) {
                const [row] = await manager.query(`INSERT INTO otps(phone,otp_code,purpose,attempts,expires_at)
                    VALUES($1,$2,$3,0,NOW()+INTERVAL '5 minutes') RETURNING id`,
                    [identifier, this.codeHash(identifier,delivery.purpose,operationToken,delivery.code),delivery.purpose]);
                challengeIds.push(row.id);
            }
            user.failedLoginAttempts=0; user.lockedUntil=null;
            await manager.getRepository(User).save(user);
            return {kind:'challenge' as const, operationToken, deliveries, challengeIds, requiresNewEmailCode:!nextGoogle};
        });
        if (result.kind === 'error') throw result.error;
        const sent = await Promise.all(result.deliveries.map(async delivery => {
            try { return await this.mail.sendOtp(delivery.email, delivery.code, delivery.purpose === OLD ? 'EMAIL_CHANGE_OLD' : 'EMAIL_CHANGE_NEW'); }
            catch { return false; }
        }));
        if (sent.some(value => !value)) {
            await this.db.query('UPDATE otps SET consumed_at=NOW() WHERE id=ANY($1::int[])', [result.challengeIds]);
            throw new AuthError('Chưa gửi được đủ mã xác nhận. Gmail hiện tại vẫn được giữ nguyên',503,'OTP_DELIVERY_FAILED');
        }
        return {operationToken:result.operationToken, currentEmail:oldEmail, newEmail,
            requiresNewEmailCode:result.requiresNewEmailCode, expiresInSeconds:300, resendAfterSeconds:60};
    }

    async confirm(actor: ProfileVerificationActor, dto: ConfirmProfileEmailChangeDto) {
        const proposal = this.parseProposal(dto.operationToken, actor);
        const result = await this.db.transaction(async manager => {
            const user = await this.lockedUser(manager, actor, proposal.oldEmail, proposal.newEmail);
            if ((user.googleSubject || null) !== proposal.oldGoogleSubject) {
                throw new AuthError('Liên kết Google đã thay đổi. Vui lòng thực hiện lại',409,'GOOGLE_LINK_CHANGED');
            }
            if (Boolean(proposal.oldGoogleSubject) !== Boolean(proposal.newGoogleSubject)) {
                throw new AuthError('Yêu cầu chuyển Google không hợp lệ',400,'EMAIL_CHANGE_INVALID');
            }
            await this.assertAvailable(manager, user.id, proposal.newEmail, proposal.newGoogleSubject);
            const identifier=this.identifier(user.id,proposal.nonce);
            const rows=await manager.query(`SELECT id,purpose,otp_code,attempts FROM otps WHERE phone=$1
                AND purpose IN ($2,$3) AND consumed_at IS NULL AND expires_at>NOW() ORDER BY id DESC FOR UPDATE`,[identifier,OLD,NEW]);
            const required=[{purpose:OLD,code:dto.currentEmailCode}];
            if (!proposal.newGoogleSubject) required.push({purpose:NEW,code:dto.newEmailCode || ''});
            let invalid=false;
            for (const input of required) {
                const row=rows.find((candidate: {purpose:string})=>candidate.purpose===input.purpose);
                if (!row) return {error:new AuthError('Mã xác nhận không đúng hoặc đã hết hạn',400,'OTP_INVALID')};
                if (Number(row.attempts)>=5) return {error:new AuthError('Mã xác nhận đã bị khóa. Vui lòng thực hiện lại',429,'OTP_LOCKED')};
                const expected=Buffer.from(this.codeHash(identifier,input.purpose,dto.operationToken,input.code),'hex');
                const stored=Buffer.from(String(row.otp_code),'hex');
                if (expected.length!==stored.length || !timingSafeEqual(expected,stored)) {
                    await manager.query('UPDATE otps SET attempts=attempts+1 WHERE id=$1',[row.id]); invalid=true;
                }
            }
            if (invalid) return {error:new AuthError('Mã xác nhận không đúng hoặc đã hết hạn',400,'OTP_INVALID')};
            // A Gmail-shaped username is an email alias; custom usernames stay unchanged.
            if (sendOtpSchema.shape.identifier.safeParse(user.username).success) user.username=proposal.newEmail;
            user.email=proposal.newEmail; user.emailVerified=true;
            user.googleSubject=proposal.newGoogleSubject; user.authVersion+=1;
            await manager.getRepository(User).save(user);
            await manager.getRepository(RefreshSession).createQueryBuilder().update().set({revokedAt:new Date()})
                .where('user_id=:userId AND revoked_at IS NULL',{userId:user.id}).execute();
            await manager.query('UPDATE otps SET consumed_at=NOW() WHERE phone=$1 AND purpose IN ($2,$3) AND consumed_at IS NULL',[identifier,OLD,NEW]);
            await manager.query(`UPDATE otps SET consumed_at=NOW() WHERE phone IN ($1,$2)
                AND purpose IN ('REGISTER','RESET') AND consumed_at IS NULL`,[proposal.oldEmail,proposal.newEmail]);
            return {email:proposal.newEmail,username:user.username,emailVerified:true,reauthenticationRequired:true};
        });
        if ('error' in result) throw result.error;
        const notices = await Promise.allSettled([
            this.mail.sendEmailChanged(proposal.oldEmail, 'OLD'),
            this.mail.sendEmailChanged(proposal.newEmail, 'NEW'),
        ]);
        return {...result, notificationAccepted: notices.every(notice => notice.status === 'fulfilled' && notice.value)};
    }
}
