import { AppDataSource } from '../config/db.config';

async function main() {
  await AppDataSource.initialize();
  console.log('✅ Connected to database. Running schema patch...');
  const queryRunner = AppDataSource.createQueryRunner();
  await queryRunner.connect();
  
  try {
    // Add tags column to products table if it doesn't exist
    await queryRunner.query(`
      ALTER TABLE "products" ADD COLUMN IF NOT EXISTS "tags" text;
    `);
    console.log('✅ Column "tags" successfully added/verified on table "products".');
  } catch (error) {
    console.error('❌ Error applying schema patch:', error);
  } finally {
    await queryRunner.release();
    await AppDataSource.destroy();
  }
}

main();
