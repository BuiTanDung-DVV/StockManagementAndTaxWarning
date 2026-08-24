import { createHmac, randomInt, randomUUID, timingSafeEqual } from 'node:crypto';
import * as bcrypt from 'bcrypt';
import * as jwt from 'jsonwebtoken';
import { OAuth2Client } from 'google-auth-library';
import { EntityManager, ILike, Repository } from 'typeorm';
import { AppDataSource } from '../config/db.config';
import { config } from '../config/env.config';
import { AuthError } from '../auth/auth.errors';
import {
  ForgotPasswordDto,
  GoogleAuthDto,
  LoginDto,
  CompleteOnboardingDto,
  RegisterDto,
  ResetPasswordDto,
  SendOtpDto,
  normalizeEmail,
} from '../auth/auth.schemas';
import { RefreshSession, User } from '../auth/entities';
import { ShopMember } from '../shop/entities';
import { ShopProfile } from '../system/entities';
import { EmailService } from './email.service';

type OtpPurpose = 'REGISTER' | 'RESET';

type AuthResult = {
  access_token: string;
  refresh_token: string;
  user: Record<string, unknown>;
  shops: unknown[];
};

const DUMMY_PASSWORD_HASH = '$2b$10$aOomly2n3KydeGDfTDO7HOoYu5HS6/EyRHWTwawmo.FiK7/9dVSMm';
const MAX_LOGIN_FAILURES = 5;
const LOGIN_LOCK_MINUTES = 15;
const MAX_OTP_ATTEMPTS = 5;
const MAX_OTP_SENDS = 3;

export class AuthService {
  private get userRepo() {
    return AppDataSource.getRepository(User);
  }
  private get memberRepo() {
    return AppDataSource.getRepository(ShopMember);
  }
  private get shopRepo() {
    return AppDataSource.getRepository(ShopProfile);
  }
  private get sessionRepo() {
    return AppDataSource.getRepository(RefreshSession);
  }
  private emailService = new EmailService();
  private googleClient = new OAuth2Client();

  private hashOtp(identifier: string, purpose: OtpPurpose, code: string): string {
    return createHmac('sha256', config.otpSecret)
      .update(`${purpose}:${identifier}:${code}`)
      .digest('hex');
  }

  private hashRefreshToken(token: string): string {
    return createHmac('sha256', config.refreshTokenSecret).update(token).digest('hex');
  }

  private hashesMatch(left: string, right: string): boolean {
    const leftBuffer = Buffer.from(left, 'hex');
    const rightBuffer = Buffer.from(right, 'hex');
    return leftBuffer.length === rightBuffer.length && timingSafeEqual(leftBuffer, rightBuffer);
  }

  private async findUserByIdentifier(
    identifier: string,
    repository: Repository<User> = this.userRepo,
  ): Promise<User | null> {
    if (identifier.includes('@')) {
      const email = normalizeEmail(identifier);
      return repository
        .createQueryBuilder('user')
        .where('LOWER(user.email) = :email OR LOWER(user.username) = :email', { email })
        .getOne();
    }
    return repository.findOne({
      where: [{ username: identifier }, { phone: identifier }],
    });
  }

  private async findVerifiedEmailUser(
    email: string,
    repository: Repository<User> = this.userRepo,
  ): Promise<User | null> {
    return repository
      .createQueryBuilder('user')
      .where('LOWER(user.email) = :email', { email })
      .andWhere('user.email_verified = true')
      .getOne();
  }

  private safeUser(user: User): Record<string, unknown> {
    return {
      id: user.id,
      username: user.username,
      role: user.role,
      fullName: user.fullName,
      email: user.email || null,
      phone: user.phone || null,
      avatarUrl: user.avatarUrl || null,
      accountType: user.accountType,
      isOnboarded: user.isOnboarded,
    };
  }

  private async getUserShops(userId: number): Promise<unknown[]> {
    const memberships = await this.memberRepo.find({
      where: { userId },
      relations: ['role'],
    });
    const shopIds = Array.from(new Set(memberships.map((item) => item.shopId)));
    const shops = shopIds.length
      ? await this.shopRepo
        .createQueryBuilder('shop')
        .where('shop.id IN (:...shopIds)', { shopIds })
        .getMany()
      : [];
    const shopById = new Map(shops.map((shop) => [shop.id, shop]));
    return memberships.map((membership) => {
      const shop = shopById.get(membership.shopId);
      let permissions: Record<string, string> = {};
      if (
        membership.memberType === 'OWNER' &&
        membership.status === 'ACTIVE' &&
        membership.isActive
      ) {
        permissions = { _owner: 'true' };
      } else if (
        membership.status === 'ACTIVE' &&
        membership.isActive &&
        membership.role?.shopId === membership.shopId &&
        membership.role.permissions
      ) {
        try {
          permissions = JSON.parse(membership.role.permissions) as Record<string, string>;
        } catch {
          permissions = {};
        }
      }
      return {
        shopId: membership.shopId,
        shopName: shop?.shopName,
        shopCode: shop?.shopCode,
        memberType: membership.memberType,
        status: membership.status,
        isActive: membership.isActive,
        role: membership.role
          ? { id: membership.role.id, name: membership.role.name }
          : null,
        permissions,
      };
    });
  }

  private async createSessionTokens(
    user: User,
    manager?: EntityManager,
    familyId: string = randomUUID(),
  ): Promise<{ accessToken: string; refreshToken: string; sessionId: string }> {
    const sessionId = randomUUID();
    const accessPayload = {
      sub: user.id,
      username: user.username,
      role: user.role,
      accountType: user.accountType,
      ver: user.authVersion,
      type: 'access',
    };
    const refreshPayload = { sub: user.id, sid: sessionId, type: 'refresh' };
    const accessToken = jwt.sign(accessPayload, config.accessTokenSecret as jwt.Secret, {
      expiresIn: String(config.jwtExpiresIn),
      jwtid: randomUUID(),
    } as jwt.SignOptions);
    const refreshToken = jwt.sign(refreshPayload, config.refreshTokenSecret as jwt.Secret, {
      expiresIn: `${config.refreshTokenExpiresInDays}d`,
      jwtid: randomUUID(),
    } as jwt.SignOptions);

    const repository = manager
      ? manager.getRepository(RefreshSession)
      : this.sessionRepo;
    await repository.save(repository.create({
      id: sessionId,
      familyId,
      userId: user.id,
      tokenHash: this.hashRefreshToken(refreshToken),
      expiresAt: new Date(Date.now() + config.refreshTokenExpiresInDays * 86_400_000),
      revokedAt: null,
      replacedBy: null,
      lastUsedAt: null,
    }));
    return { accessToken, refreshToken, sessionId };
  }

  private async issueAuthResult(user: User): Promise<AuthResult> {
    const shops = await this.getUserShops(user.id);
    const tokens = await this.createSessionTokens(user);
    return {
      access_token: tokens.accessToken,
      refresh_token: tokens.refreshToken,
      user: this.safeUser(user),
      shops,
    };
  }

  private async verifyOtp(
    manager: EntityManager,
    identifier: string,
    purpose: OtpPurpose,
    otpCode: string,
  ): Promise<void> {
    const rows = await manager.query(
      `SELECT id, otp_code, attempts
       FROM otps
       WHERE phone = $1 AND purpose = $2 AND consumed_at IS NULL AND expires_at > NOW()
       ORDER BY created_at DESC
       LIMIT 1
       FOR UPDATE`,
      [identifier, purpose],
    );
    const otp = rows[0];
    if (!otp) {
      throw new AuthError('Mã OTP không đúng hoặc đã hết hạn', 400, 'OTP_INVALID');
    }
    if (Number(otp.attempts) >= MAX_OTP_ATTEMPTS) {
      throw new AuthError('Mã OTP đã bị khóa do nhập sai quá nhiều lần', 429, 'OTP_LOCKED');
    }
    const actualHash = this.hashOtp(identifier, purpose, otpCode);
    if (!this.hashesMatch(String(otp.otp_code), actualHash)) {
      await manager.query('UPDATE otps SET attempts = attempts + 1 WHERE id = $1', [otp.id]);
      throw new AuthError('Mã OTP không đúng hoặc đã hết hạn', 400, 'OTP_INVALID');
    }
    await manager.query(
      'UPDATE otps SET consumed_at = NOW() WHERE phone = $1 AND purpose = $2 AND consumed_at IS NULL',
      [identifier, purpose],
    );
  }

  async register(dto: RegisterDto): Promise<AuthResult> {
    const email = normalizeEmail(dto.username);
    const user = await AppDataSource.transaction(async (manager) => {
      await manager.query('SELECT pg_advisory_xact_lock(hashtext($1))', [email]);
      const repository = manager.getRepository(User);
      if (await this.findUserByIdentifier(email, repository)) {
        throw new AuthError('Địa chỉ Gmail đã tồn tại', 409, 'EMAIL_EXISTS');
      }
      await this.verifyOtp(manager, email, 'REGISTER', dto.otpCode);
      return repository.save(repository.create({
        username: email,
        email,
        emailVerified: true,
        passwordHash: await bcrypt.hash(dto.password, 12),
        fullName: dto.fullName,
        accountType: null,
        role: 'STAFF',
        isActive: true,
        isOnboarded: false,
        googleSubject: null,
        failedLoginAttempts: 0,
        lockedUntil: null,
        authVersion: 0,
      }));
    });
    return this.issueAuthResult(user);
  }

  async login(dto: LoginDto): Promise<AuthResult> {
    const identifier = dto.username.includes('@')
      ? normalizeEmail(dto.username)
      : dto.username.trim();
    const user = await this.findUserByIdentifier(identifier);
    const passwordValid = await bcrypt.compare(
      dto.password,
      user?.passwordHash || DUMMY_PASSWORD_HASH,
    );

    if (user?.lockedUntil && user.lockedUntil.getTime() > Date.now()) {
      throw new AuthError('Tài khoản tạm khóa. Vui lòng thử lại sau', 429, 'ACCOUNT_LOCKED');
    }
    if (!user || !passwordValid) {
      if (user) {
        const failures = user.failedLoginAttempts + 1;
        user.failedLoginAttempts = failures;
        if (failures >= MAX_LOGIN_FAILURES) {
          user.lockedUntil = new Date(Date.now() + LOGIN_LOCK_MINUTES * 60_000);
          user.failedLoginAttempts = 0;
        }
        await this.userRepo.save(user);
      }
      throw new AuthError('Sai Gmail hoặc mật khẩu', 401, 'INVALID_CREDENTIALS');
    }
    if (!user.isActive) {
      throw new AuthError('Tài khoản đã bị khóa', 401, 'ACCOUNT_INACTIVE');
    }
    user.failedLoginAttempts = 0;
    user.lockedUntil = null;
    await this.userRepo.save(user);
    return this.issueAuthResult(user);
  }

  async googleAuth(dto: GoogleAuthDto): Promise<AuthResult> {
    if (config.googleClientIds.length === 0) {
      throw new AuthError('Google Sign-In chưa được cấu hình', 503, 'GOOGLE_NOT_CONFIGURED');
    }
    let payload;
    try {
      const ticket = await this.googleClient.verifyIdToken({
        idToken: dto.idToken,
        audience: config.googleClientIds,
      });
      payload = ticket.getPayload();
    } catch {
      throw new AuthError('Google ID token không hợp lệ', 401, 'GOOGLE_TOKEN_INVALID');
    }
    const email = payload?.email ? normalizeEmail(payload.email) : '';
    if (!payload?.sub || !payload.email_verified || !email.endsWith('@gmail.com')) {
      throw new AuthError('Chỉ chấp nhận tài khoản Gmail đã được Google xác minh', 401, 'GOOGLE_EMAIL_INVALID');
    }

    const user = await AppDataSource.transaction(async (manager) => {
      await manager.query('SELECT pg_advisory_xact_lock(hashtext($1))', [email]);
      const repository = manager.getRepository(User);
      let current = await repository.findOne({ where: { googleSubject: payload.sub } });
      current ??= await this.findVerifiedEmailUser(email, repository);
      if (!current && !dto.createIfMissing) {
        throw new AuthError('Chưa có tài khoản. Vui lòng đăng ký bằng Google trước', 404, 'ACCOUNT_NOT_FOUND');
      }
      if (!current) {
        return repository.save(repository.create({
          username: email,
          email,
          emailVerified: true,
          passwordHash: null,
          fullName: (payload.name || email.split('@')[0]).slice(0, 100),
          avatarUrl: payload.picture || undefined,
          accountType: null,
          role: 'STAFF',
          isActive: true,
          isOnboarded: false,
          googleSubject: payload.sub,
          failedLoginAttempts: 0,
          lockedUntil: null,
          authVersion: 0,
        }));
      }
      if (current.googleSubject && current.googleSubject !== payload.sub) {
        throw new AuthError('Gmail đã liên kết với tài khoản Google khác', 409, 'GOOGLE_LINK_CONFLICT');
      }
      if (!current.isActive) {
        throw new AuthError('Tài khoản đã bị khóa', 401, 'ACCOUNT_INACTIVE');
      }
      current.googleSubject = payload.sub;
      current.email = email;
      current.emailVerified = true;
      if (!current.avatarUrl && payload.picture) current.avatarUrl = payload.picture;
      return repository.save(current);
    });
    return this.issueAuthResult(user);
  }

  async refreshToken(refreshToken: string): Promise<{ access_token: string; refresh_token: string }> {
    if (!refreshToken) {
      throw new AuthError('Thiếu refresh token', 401, 'REFRESH_MISSING');
    }
    let decoded: jwt.JwtPayload;
    try {
      decoded = jwt.verify(refreshToken, config.refreshTokenSecret) as jwt.JwtPayload;
    } catch {
      throw new AuthError('Phiên đăng nhập không hợp lệ', 401, 'REFRESH_INVALID');
    }
    if (decoded.type !== 'refresh' || !decoded.sub || typeof decoded.sid !== 'string') {
      throw new AuthError('Phiên đăng nhập không hợp lệ', 401, 'REFRESH_INVALID');
    }

    const outcome = await AppDataSource.transaction(async (manager) => {
      const repository = manager.getRepository(RefreshSession);
      const session = await repository
        .createQueryBuilder('session')
        .setLock('pessimistic_write')
        .where('session.id = :id', { id: decoded.sid })
        .getOne();
      const presentedHash = this.hashRefreshToken(refreshToken);
      if (!session || !this.hashesMatch(session.tokenHash, presentedHash)) {
        throw new AuthError('Phiên đăng nhập không hợp lệ', 401, 'REFRESH_INVALID');
      }
      if (session.revokedAt) {
        await repository.update({ familyId: session.familyId }, { revokedAt: new Date() });
        return { kind: 'reused' as const };
      }
      if (session.expiresAt.getTime() <= Date.now()) {
        session.revokedAt = new Date();
        await repository.save(session);
        throw new AuthError('Phiên đăng nhập đã hết hạn', 401, 'REFRESH_EXPIRED');
      }
      const user = await manager.getRepository(User).findOne({
        where: { id: Number(decoded.sub) },
      });
      if (!user?.isActive) {
        throw new AuthError('Tài khoản không còn hoạt động', 401, 'ACCOUNT_INACTIVE');
      }
      const next = await this.createSessionTokens(user, manager, session.familyId);
      session.revokedAt = new Date();
      session.lastUsedAt = new Date();
      session.replacedBy = next.sessionId;
      await repository.save(session);
      return {
        kind: 'tokens' as const,
        access_token: next.accessToken,
        refresh_token: next.refreshToken,
      };
    });
    if (outcome.kind === 'reused') {
      throw new AuthError('Phát hiện refresh token đã được sử dụng lại', 401, 'REFRESH_REUSED');
    }
    return {
      access_token: outcome.access_token,
      refresh_token: outcome.refresh_token,
    };
  }

  async logout(refreshToken?: string): Promise<void> {
    if (!refreshToken) return;
    try {
      const decoded = jwt.verify(refreshToken, config.refreshTokenSecret) as jwt.JwtPayload;
      if (typeof decoded.sid !== 'string') return;
      const session = await this.sessionRepo.findOne({ where: { id: decoded.sid } });
      if (session && this.hashesMatch(session.tokenHash, this.hashRefreshToken(refreshToken))) {
        session.revokedAt = new Date();
        await this.sessionRepo.save(session);
      }
    } catch {
      return;
    }
  }

  async revokeAllSessions(userId: number): Promise<void> {
    await this.sessionRepo
      .createQueryBuilder()
      .update()
      .set({ revokedAt: new Date() })
      .where('user_id = :userId AND revoked_at IS NULL', { userId })
      .execute();
  }

  async sendOtp(dto: SendOtpDto): Promise<{ success: true; message: string; otp?: string }> {
    const identifier = normalizeEmail(dto.identifier);
    const purpose: OtpPurpose = dto.isRegistration ? 'REGISTER' : 'RESET';
    const existing = await this.findUserByIdentifier(identifier);
    if (purpose === 'REGISTER' && existing) {
      throw new AuthError('Địa chỉ Gmail đã tồn tại', 409, 'EMAIL_EXISTS');
    }
    if (purpose === 'RESET' && !existing) {
      return { success: true, message: 'Nếu Gmail tồn tại, mã OTP sẽ được gửi' };
    }
    const recent = await AppDataSource.query(
      `SELECT COUNT(*)::int AS count FROM otps
       WHERE phone = $1 AND purpose = $2 AND created_at > NOW() - INTERVAL '15 minutes'`,
      [identifier, purpose],
    );
    if (Number(recent[0]?.count || 0) >= MAX_OTP_SENDS) {
      throw new AuthError('Bạn đã yêu cầu quá nhiều mã OTP. Vui lòng thử lại sau 15 phút', 429, 'OTP_RATE_LIMIT');
    }

    const otpCode = randomInt(100000, 1000000).toString();
    const otpHash = this.hashOtp(identifier, purpose, otpCode);
    const inserted = await AppDataSource.query(
      `INSERT INTO otps (phone, otp_code, purpose, attempts, expires_at)
       VALUES ($1, $2, $3, 0, NOW() + INTERVAL '5 minutes')
       RETURNING id`,
      [identifier, otpHash, purpose],
    );
    const sent = await this.emailService.sendOtp(identifier, otpCode);
    if (!sent) {
      await AppDataSource.query('DELETE FROM otps WHERE id = $1', [inserted[0].id]);
      throw new AuthError('Không thể gửi OTP. Vui lòng thử lại sau', 503, 'OTP_DELIVERY_FAILED');
    }
    const exposeOtp = process.env.NODE_ENV !== 'production' && process.env.OTP_DEBUG_RESPONSE === 'true';
    return {
      success: true,
      message: purpose === 'RESET'
        ? 'Nếu Gmail tồn tại, mã OTP sẽ được gửi'
        : 'Đã gửi OTP thành công',
      otp: exposeOtp ? otpCode : undefined,
    };
  }

  async forgotPassword(dto: ForgotPasswordDto) {
    return this.sendOtp({
      identifier: dto.identifier,
      isRegistration: false,
      checkExists: true,
    });
  }

  async resetPassword(dto: ResetPasswordDto): Promise<{ updated: true }> {
    const identifier = normalizeEmail(dto.identifier);
    await AppDataSource.transaction(async (manager) => {
      const repository = manager.getRepository(User);
      const user = await this.findUserByIdentifier(identifier, repository);
      if (!user) {
        throw new AuthError('Mã OTP không đúng hoặc đã hết hạn', 400, 'OTP_INVALID');
      }
      await this.verifyOtp(manager, identifier, 'RESET', dto.otpCode);
      user.passwordHash = await bcrypt.hash(dto.newPassword, 12);
      user.authVersion += 1;
      user.failedLoginAttempts = 0;
      user.lockedUntil = null;
      await repository.save(user);
      await manager.getRepository(RefreshSession)
        .createQueryBuilder()
        .update()
        .set({ revokedAt: new Date() })
        .where('user_id = :userId AND revoked_at IS NULL', { userId: user.id })
        .execute();
    });
    return { updated: true };
  }

  async searchShops(q: string) {
    if (!q || q.trim().length === 0) return [];
    return this.shopRepo.find({
      where: { shopName: ILike(`%${q.trim()}%`) },
      take: 10,
      select: ['id', 'shopName', 'address', 'logoUrl'],
    });
  }

  async completeOnboarding(userId: number, dto: CompleteOnboardingDto) {
    let status = 'ACTIVE';
    let completedUser: User | null = null;

    await AppDataSource.transaction(async (manager) => {
      const user = await manager
        .getRepository(User)
        .createQueryBuilder('user')
        .setLock('pessimistic_write')
        .where('user.id = :userId', { userId })
        .getOne();
      if (!user) throw new AuthError('Không tìm thấy tài khoản', 404, 'USER_NOT_FOUND');
      if (user.isOnboarded) {
        throw new AuthError(
          'Tài khoản đã hoàn tất thiết lập',
          409,
          'ONBOARDING_ALREADY_COMPLETED',
        );
      }

      if (dto.username) {
        const existing = await manager.getRepository(User).findOne({
          where: { username: dto.username },
        });
        if (existing && existing.id !== user.id) {
          throw new AuthError('Tên đăng nhập đã tồn tại', 409, 'USERNAME_EXISTS');
        }
        user.username = dto.username;
      }
      if (dto.phone) {
        const existing = await manager.getRepository(User).findOne({
          where: { phone: dto.phone },
        });
        if (existing && existing.id !== user.id) {
          throw new AuthError('Số điện thoại đã tồn tại', 409, 'PHONE_EXISTS');
        }
        user.phone = dto.phone;
      }
      user.fullName = dto.fullName;

      // accountType chỉ mô tả luồng nghiệp vụ. Quyền OWNER/EMPLOYEE vẫn do
      // backend cấp khi tạo cửa hàng hoặc gửi yêu cầu tham gia.
      user.accountType = dto.accountType;
      user.isOnboarded = true;
      await manager.save(user);
      if (user.accountType === 'SHOP') {
        const charSet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
        let code = '';
        for (let i = 0; i < 6; i++) code += charSet[randomInt(0, charSet.length)];
        const shop = manager.create(ShopProfile, {
          shopName: dto.shopName?.toString().trim() || user.fullName,
          ownerName: dto.ownerName?.toString().trim() || user.fullName,
          address: dto.address?.toString().trim() || '',
          shopCode: code,
        });
        const savedShop = await manager.save(shop);
        await manager.save(manager.create(ShopMember, {
          shopId: savedShop.id,
          userId: user.id,
          memberType: 'OWNER',
          status: 'ACTIVE',
          isActive: true,
        }));
      } else if (user.accountType === 'PERSONAL') {
        const existingMember = await manager.findOne(ShopMember, { where: { userId: user.id } });
        if (existingMember) {
          status = existingMember.status;
        } else {
          const submittedShopCode = dto.shopCode?.toString().trim();
          if (submittedShopCode) {
            const submittedShopId = dto.shopId ? parseInt(dto.shopId, 10) : null;
            const whereClause: Record<string, unknown> = { shopCode: submittedShopCode };
            if (submittedShopId) whereClause.id = submittedShopId;
            const targetShop = await manager.findOne(ShopProfile, { where: whereClause });
            if (!targetShop) throw new Error('Không tìm thấy cửa hàng phù hợp');
            await manager.save(manager.create(ShopMember, {
              shopId: targetShop.id,
              userId: user.id,
              memberType: 'EMPLOYEE',
              status: 'PENDING',
              isActive: true,
            }));
            status = 'PENDING';
          } else {
            throw new AuthError(
              'Vui lòng chọn cửa hàng hoặc nhập mã cửa hàng',
              422,
              'SHOP_REQUIRED',
            );
          }
        }
      }
      completedUser = user;
    });
    if (!completedUser) {
      throw new AuthError('Không thể hoàn tất thiết lập', 500, 'ONBOARDING_FAILED');
    }
    return {
      updated: true,
      status,
      user: this.safeUser(completedUser),
    };
  }
}
