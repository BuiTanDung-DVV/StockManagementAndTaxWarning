"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AppDataSource = void 0;
const typeorm_1 = require("typeorm");
const env_config_1 = require("./env.config");
const path = require("path");
exports.AppDataSource = new typeorm_1.DataSource({
    type: 'mssql',
    host: env_config_1.config.dbHost,
    database: env_config_1.config.dbDatabase,
    synchronize: env_config_1.config.dbSync,
    driver: require('mssql/msnodesqlv8'),
    options: {
        encrypt: false,
        trustServerCertificate: true,
    },
    extra: {
        connectionString: `Driver={ODBC Driver 17 for SQL Server};Server=${env_config_1.config.dbHost};Database=${env_config_1.config.dbDatabase};Trusted_Connection=Yes;`,
    },
    entities: [path.join(__dirname, '../**/entities{.ts,.js}')],
    migrations: [],
    subscribers: [],
});
//# sourceMappingURL=db.config.js.map