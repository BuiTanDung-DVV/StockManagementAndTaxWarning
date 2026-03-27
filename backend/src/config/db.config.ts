import { DataSource } from 'typeorm';
import { config } from './env.config';
import * as path from 'path';

export const AppDataSource = new DataSource({
  type: 'mssql',
  host: config.dbHost,
  database: config.dbDatabase,
  synchronize: config.dbSync,
  driver: require('mssql/msnodesqlv8'),
  options: {
    encrypt: false,
    trustServerCertificate: true,
  },
  extra: {
    connectionString: `Driver={ODBC Driver 17 for SQL Server};Server=${config.dbHost};Database=${config.dbDatabase};Trusted_Connection=Yes;`,
  },
  // Entities in this repo live in `*/entities.ts` (e.g. `src/auth/entities.ts`).
  // Keep the glob narrow to avoid accidentally loading non-entity modules.
  entities: [
    path.join(__dirname, '../**/entities{.ts,.js}'),
    path.join(__dirname, '../**/*.entity{.ts,.js}'),
  ],
  migrations: [],
  subscribers: [],
});
