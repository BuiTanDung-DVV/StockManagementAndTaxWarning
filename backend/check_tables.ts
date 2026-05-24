import { AppDataSource } from './src/config/db.config';

AppDataSource.initialize().then(async () => {
  const res = await AppDataSource.query("SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_name IN ('journal_entries', 'journal_lines')");
  console.log("TABLES:", res);
  process.exit(0);
}).catch(e => {
  console.error(e);
  process.exit(1);
});
