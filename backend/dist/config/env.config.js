"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.config = void 0;
const dotenv = require("dotenv");
dotenv.config();
exports.config = {
    port: process.env.PORT || 8080,
    dbHost: process.env.DB_HOST || 'localhost',
    dbDatabase: process.env.DB_DATABASE || 'QLKH',
    dbUrl: process.env.DATABASE_URL || '',
    dbSync: process.env.DB_SYNC === 'true',
    jwtSecret: process.env.JWT_SECRET || 'secretKey',
    jwtExpiresIn: process.env.JWT_EXPIRES_IN || '1d',
};
//# sourceMappingURL=env.config.js.map