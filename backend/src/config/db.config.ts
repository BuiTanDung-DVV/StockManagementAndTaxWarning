import { DataSource } from 'typeorm';
import { config } from './env.config';
import * as path from 'path';

import { AuditLogSubscriber } from '../system/audit-log.subscriber';

export const AppDataSource = new DataSource({
  type: 'postgres',
  ...(config.dbUrl 
    ? { url: config.dbUrl, ssl: { rejectUnauthorized: false } } 
    : {
        host: config.dbHost,
        database: config.dbDatabase,
      }),
  extra: {
    max: 10,
    connectionTimeoutMillis: 3000,
    idleTimeoutMillis: 10000,
  },
  synchronize: false, // Schema managed by Supabase — never auto-sync
  entities: [
    path.join(__dirname, '../**/entities{.ts,.js}'),
    path.join(__dirname, '../**/*.entity{.ts,.js}'),
  ],
  migrations: [],
  subscribers: [AuditLogSubscriber],
});
