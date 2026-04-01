"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AuthService = void 0;
const db_config_1 = require("../config/db.config");
const entities_1 = require("../auth/entities");
const entities_2 = require("../shop/entities");
const jwt = require("jsonwebtoken");
const bcrypt = require("bcrypt");
const env_config_1 = require("../config/env.config");
class AuthService {
    constructor() {
        this.userRepo = db_config_1.AppDataSource.getRepository(entities_1.User);
        this.memberRepo = db_config_1.AppDataSource.getRepository(entities_2.ShopMember);
    }
    async register(dto) {
        const existing = await this.userRepo.findOne({ where: { username: dto.username } });
        if (existing)
            throw new Error('Username already exists');
        const password = dto?.password || dto?.passwordHash;
        if (!password)
            throw new Error('Missing password');
        const user = this.userRepo.create({
            ...dto,
            passwordHash: await bcrypt.hash(password, 10),
        });
        return this.userRepo.save(user);
    }
    async login(dto) {
        const user = await this.userRepo.findOne({ where: { username: dto.username } });
        const password = (dto?.password || '').toString();
        if (!user || !(await bcrypt.compare(password, user.passwordHash || ''))) {
            throw new Error('Invalid credentials');
        }
        if (!user.isActive) {
            throw new Error('Account is inactive');
        }
        const payload = { sub: user.id, username: user.username, role: user.role, accountType: user.accountType };
        const accessToken = jwt.sign(payload, env_config_1.config.jwtSecret, { expiresIn: String(env_config_1.config.jwtExpiresIn) });
        let shops = [];
        try {
            const memberships = await this.memberRepo.find({
                where: { userId: user.id, isActive: true },
                relations: ['role'],
            });
            shops = memberships.map(m => {
                let permissions = {};
                if (m.memberType === 'OWNER') {
                    permissions = { _owner: 'true' };
                }
                else if (m.role?.permissions) {
                    try {
                        permissions = JSON.parse(m.role.permissions);
                    }
                    catch {
                        permissions = {};
                    }
                }
                return {
                    shopId: m.shopId,
                    memberType: m.memberType,
                    role: m.role ? { id: m.role.id, name: m.role.name } : null,
                    permissions,
                };
            });
        }
        catch (e) {
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
            },
            shops,
        };
    }
    async forgotPassword(dto) {
        const identifier = (dto?.identifier || '').toString().trim();
        if (!identifier)
            throw new Error('Missing identifier');
        const user = await this.userRepo.findOne({ where: { username: identifier } });
        if (!user) {
            return { sent: true };
        }
        return { sent: true, userId: user.id };
    }
    async resetPassword(dto) {
        const identifier = (dto?.identifier || '').toString().trim();
        const newPassword = (dto?.newPassword || '').toString();
        if (!identifier || !newPassword)
            throw new Error('Missing identifier or newPassword');
        const user = await this.userRepo.findOne({ where: { username: identifier } });
        if (!user)
            throw new Error('User not found');
        user.passwordHash = await bcrypt.hash(newPassword, 10);
        await this.userRepo.save(user);
        return { updated: true };
    }
}
exports.AuthService = AuthService;
//# sourceMappingURL=auth.service.js.map