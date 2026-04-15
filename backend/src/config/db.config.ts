import { DataSource } from 'typeorm';
import { config } from './env.config';
import * as path from 'path';

export const AppDataSource = new DataSource({
  type: 'postgres',
  ...(config.dbUrl 
    ? { url: config.dbUrl, ssl: { rejectUnauthorized: false } } 
    : {
        host: config.dbHost,
        database: config.dbDatabase,
      }),
  synchronize: false, // Schema managed by Supabase — never auto-sync
  entities: [
    path.join(__dirname, '../**/entities{.ts,.js}'),
    path.join(__dirname, '../**/*.entity{.ts,.js}'),
  ],
  migrations: [],
  subscribers: [],
});
