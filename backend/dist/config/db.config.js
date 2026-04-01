"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AppDataSource = void 0;
const typeorm_1 = require("typeorm");
const env_config_1 = require("./env.config");
const path = require("path");
exports.AppDataSource = new typeorm_1.DataSource({
    type: 'postgres',
    ...(env_config_1.config.dbUrl
        ? { url: env_config_1.config.dbUrl, ssl: { rejectUnauthorized: false } }
        : {
            host: env_config_1.config.dbHost,
            database: env_config_1.config.dbDatabase,
        }),
    synchronize: env_config_1.config.dbSync,
    entities: [
        path.join(__dirname, '../**/entities{.ts,.js}'),
        path.join(__dirname, '../**/*.entity{.ts,.js}'),
    ],
    migrations: [],
    subscribers: [],
});
//# sourceMappingURL=db.config.js.map