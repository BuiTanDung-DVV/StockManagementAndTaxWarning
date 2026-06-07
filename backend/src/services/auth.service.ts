import { AppDataSource } from '../config/db.config';
import { User } from '../auth/entities';
import { ShopMember } from '../shop/entities';
import { ShopProfile } from '../system/entities';
import { ILike } from 'typeorm';
import * as jwt from 'jsonwebtoken';
import * as bcrypt from 'bcrypt';
import { config } from '../config/env.config';
import { SmsService } from './sms.service';
import { EmailService } from './email.service';

export class AuthService {
    private userRepo = AppDataSource.getRepository(User);
    private memberRepo = AppDataSource.getRepository(ShopMember);
    private shopRepo = AppDataSource.getRepository(ShopProfile);
    private smsService = new SmsService();
    private emailService = new EmailService();

    async register(dto: Partial<User> & { otpCode?: string }) {
        const identifier = (dto.username || '').toString().trim();
        const isPhone = /^(0|\+84)\d{8,9}$/.test(identifier);
        const isEmail = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(identifier);

        if (isPhone) {
            dto.phone = identifier;
        } else if (isEmail) {
            dto.email = identifier;
        }
        (dto as any).isOnboarded = false;

        const existing = await this.userRepo.findOne({
            where: [
                { username: identifier },
                ...(isPhone ? [{ phone: identifier }] : []),
                ...(isEmail ? [{ email: identifier }] : [])
            ]
        });
        if (existing) throw new Error('Tài khoản, SĐT hoặc Email đã tồn tại');

        // Verify OTP if registering with phone number or email
        if (isPhone || isEmail) {
            const otpCode = (dto.otpCode || '').toString().trim();
            if (!otpCode) throw new Error('Mã OTP là bắt buộc khi đăng ký');

            const validOtp = await AppDataSource.query(`
                SELECT * FROM otps 
                WHERE phone = $1 AND otp_code = $2 AND expires_at > NOW() 
                ORDER BY created_at DESC LIMIT 1
            `, [identifier, otpCode]);

            if (!validOtp || validOtp.length === 0) {
                throw new Error('Mã xác thực OTP không đúng hoặc đã hết hạn');
            }

            // Cleanup OTP
            await AppDataSource.query(`DELETE FROM otps WHERE phone = $1`, [identifier]);
        }
        
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
                { phone: identifier },
                { email: identifier }
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
        const refreshToken = jwt.sign(
            payload,
            config.jwtSecret as jwt.Secret,
            { expiresIn: '7d' } as jwt.SignOptions,
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
            refresh_token: refreshToken,
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

    async refreshToken(refreshToken: string) {
        if (!refreshToken) throw new Error('Missing refresh token');
        let decoded: any;
        try {
            decoded = jwt.verify(refreshToken, config.jwtSecret as jwt.Secret);
        } catch (e) {
            throw new Error('Invalid refresh token');
        }

        const user = await this.userRepo.findOne({ where: { id: decoded.sub } });
        if (!user || !user.isActive) throw new Error('Invalid user or inactive');

        const payload = { sub: user.id, username: user.username, role: user.role, accountType: user.accountType };
        const newAccessToken = jwt.sign(
            payload,
            config.jwtSecret as jwt.Secret,
            { expiresIn: String(config.jwtExpiresIn) } as jwt.SignOptions,
        );
        const newRefreshToken = jwt.sign(
            payload,
            config.jwtSecret as jwt.Secret,
            { expiresIn: '7d' } as jwt.SignOptions,
        );

        return { access_token: newAccessToken, refresh_token: newRefreshToken };
    }

    async sendOtp(dto: { phone?: string; identifier?: string; checkExists?: boolean }) {
        const identifier = (dto?.identifier || dto?.phone || '').toString().trim();
        if (!identifier) throw new Error('Thiếu số điện thoại hoặc email');

        const isPhone = /^(0|\+84)\d{8,11}$/.test(identifier);
        const isEmail = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(identifier);
        
        if (!isPhone && !isEmail) throw new Error('Định dạng Số điện thoại hoặc Email không hợp lệ');

        if (dto.checkExists) {
            const user = await this.userRepo.findOne({
                where: [
                    { username: identifier },
                    { phone: identifier },
                    { email: identifier }
                ]
            });
            if (!user) throw new Error('Số điện thoại hoặc Email này chưa được đăng ký trong hệ thống');
        }

        // Generate 6 digit OTP
        const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
        
        // Save to DB otps table
        await AppDataSource.query(`
            INSERT INTO otps (phone, otp_code, expires_at)
            VALUES ($1, $2, NOW() + INTERVAL '2 minutes')
        `, [identifier, otpCode]);

        // Send actual SMS or Email
        let sent = false;
        if (isEmail) {
            sent = await this.emailService.sendOtp(identifier, otpCode);
        } else {
            sent = await this.smsService.sendOtp(identifier, otpCode);
        }
        
        // In sandbox mode, return otp for testing, else don't return it
        const isSandbox = !process.env.SMTP_USER || process.env.SMTP_USER === 'your-email@gmail.com';
        
        if (!sent) {
            throw new Error('Không thể gửi OTP do lỗi hệ thống hoặc cấu hình chưa đúng.');
        }

        return { 
            success: true, 
            message: 'Đã gửi OTP thành công', 
            otp: isSandbox ? otpCode : undefined 
        };
    }

    async forgotPassword(dto: any) {
        const identifier = (dto?.identifier || '').toString().trim();
        if (!identifier) throw new Error('Vui lòng nhập số điện thoại hoặc email');

        const user = await this.userRepo.findOne({
            where: [
                { username: identifier },
                { phone: identifier },
                { email: identifier }
            ]
        });
        if (!user) {
            throw new Error('Số điện thoại hoặc email này chưa được đăng ký trong hệ thống');
        }

        // Generate OTP and send
        return this.sendOtp({ identifier: user.email || user.phone || identifier, checkExists: false });
    }

    async resetPassword(dto: any) {
        const identifier = (dto?.identifier || '').toString().trim();
        const newPassword = (dto?.newPassword || '').toString();
        const otpCode = (dto?.otpCode || '').toString().trim();
        if (!identifier || !newPassword || !otpCode) throw new Error('Vui lòng nhập đầy đủ thông tin (tài khoản, mật khẩu mới, mã OTP)');

        const user = await this.userRepo.findOne({
            where: [
                { username: identifier },
                { phone: identifier },
                { email: identifier }
            ]
        });
        if (!user) throw new Error('Không tìm thấy tài khoản');

        // Verify OTP
        const validOtp = await AppDataSource.query(`
            SELECT * FROM otps 
            WHERE phone = $1 AND otp_code = $2 AND expires_at > NOW() 
            ORDER BY created_at DESC LIMIT 1
        `, [user.email || user.phone || identifier, otpCode]);

        if (!validOtp || validOtp.length === 0) {
            throw new Error('Mã xác thực OTP không đúng hoặc đã hết hạn');
        }

        // Cleanup OTP
        await AppDataSource.query(`DELETE FROM otps WHERE phone = $1`, [user.email || user.phone || identifier]);

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
                const existingMember = await manager.findOne(ShopMember, { where: { userId: user.id } });
                if (existingMember) {
                    status = existingMember.status;
                } else {
                    const submittedShopCode = dto.shopCode?.toString().trim();
                    if (submittedShopCode) {
                        const submittedShopId = dto.shopId ? parseInt(dto.shopId, 10) : null;
                        const whereClause: any = { shopCode: submittedShopCode };
                        if (submittedShopId) whereClause.id = submittedShopId;

                        const targetShop = await manager.findOne(ShopProfile, { where: whereClause });
                        if (!targetShop) throw new Error('Không tìm thấy Cửa hàng khớp với yêu cầu của bạn.');

                        const member = manager.create(ShopMember, {
                            shopId: targetShop.id,
                            userId: user.id,
                            memberType: 'EMPLOYEE',
                            status: 'PENDING',
                            isActive: true,
                        });
                        await manager.save(member);
                        status = 'PENDING';
                    } else {
                        status = 'ACTIVE';
                    }
                }
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
