import { AppDataSource } from '../config/db.config';

async function migrate() {
  await AppDataSource.initialize();
  console.log('DB Connected. Running migrations...');

  try {
    // 1. Add is_onboarded to users
    await AppDataSource.query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS is_onboarded BOOLEAN DEFAULT FALSE;`);
    console.log('Added is_onboarded to users.');

    // 2. Add shop_code to shop_profiles
    await AppDataSource.query(`ALTER TABLE shop_profiles ADD COLUMN IF NOT EXISTS shop_code VARCHAR(20);`);
    await AppDataSource.query(`CREATE UNIQUE INDEX IF NOT EXISTS idx_shop_profiles_code ON shop_profiles(shop_code);`);
    await AppDataSource.query(`CREATE INDEX IF NOT EXISTS idx_shop_profiles_name ON shop_profiles(shop_name);`);
    console.log('Added shop_code and indexes to shop_profiles.');

    // 3. Add status to shop_members & clean up isActive
    await AppDataSource.query(`ALTER TABLE shop_members ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'PENDING';`);
    await AppDataSource.query(`CREATE UNIQUE INDEX IF NOT EXISTS idx_shop_member_unique_status ON shop_members(shop_id, user_id) WHERE status IN ('PENDING', 'ACTIVE');`);
    console.log('Added status and unique index to shop_members.');

    // Update existing members (assuming older ones were active)
    await AppDataSource.query(`UPDATE shop_members SET status = 'ACTIVE' WHERE is_active = true AND status = 'PENDING';`);
    await AppDataSource.query(`UPDATE shop_members SET status = 'INACTIVE' WHERE is_active = false AND status = 'PENDING';`);

    console.log('Migration completed successfully.');
  } catch (error) {
    console.error('Migration failed:', error);
  } finally {
    await AppDataSource.destroy();
  }
}

migrate();
