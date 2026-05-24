import { AppDataSource } from './src/config/db.config';
import * as fs from 'fs';

AppDataSource.initialize().then(async () => {
  const sql = fs.readFileSync('./database/20260524_create_journal_ledger.sql', 'utf-8');
  await AppDataSource.query(sql);
  console.log("Journal tables created successfully");
  process.exit(0);
}).catch(e => {
  console.error("Error creating journal tables:", e);
  process.exit(1);
});
