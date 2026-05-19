import { AppDataSource } from './src/config/db.config';
async function run() {
  await AppDataSource.initialize();
  await AppDataSource.query("ALTER TABLE purchases_without_invoice ADD COLUMN IF NOT EXISTS approval_status VARCHAR(20) DEFAULT 'PENDING'");
  await AppDataSource.query("ALTER TABLE purchases_without_invoice ADD COLUMN IF NOT EXISTS approval_notes VARCHAR(500)");
  await AppDataSource.query("ALTER TABLE purchases_without_invoice ADD COLUMN IF NOT EXISTS approved_at TIMESTAMP");
  await AppDataSource.query("ALTER TABLE purchases_without_invoice ADD COLUMN IF NOT EXISTS approved_by INT");
  console.log('Done');
  await AppDataSource.destroy();
}
run().catch(console.error);
