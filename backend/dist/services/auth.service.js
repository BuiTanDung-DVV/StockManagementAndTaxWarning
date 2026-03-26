"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AuthService = void 0;
const db_config_1 = require("../config/db.config");
const entities_1 = require("../auth/entities");
const jwt = require("jsonwebtoken");
const bcrypt = require("bcrypt");
const env_config_1 = require("../config/env.config");
class AuthService {
    constructor() {
        this.userRepo = db_config_1.AppDataSource.getRepository(entities_1.User);
    }
    async register(dto) {
        const existing = await this.userRepo.findOne({ where: { username: dto.username } });
        if (existing)
            throw new Error('Username already exists');
        const password = dto?.password;
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
        const payload = { sub: user.id, username: user.username, role: user.role };
        const accessToken = jwt.sign(payload, env_config_1.config.jwtSecret, { expiresIn: String(env_config_1.config.jwtExpiresIn) });
        return {
            access_token: accessToken,
            user: { id: user.id, username: user.username, role: user.role, fullName: user.fullName }
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