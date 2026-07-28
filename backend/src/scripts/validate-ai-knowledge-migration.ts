import 'reflect-metadata';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { AppDataSource } from '../config/db.config';

async function main(): Promise<void> {
  const migrationFiles = [
    '20260728_create_ai_knowledge_documents.sql',
    '20260728_fix_daily_closing_multi_shop_unique.sql',
  ];

  await AppDataSource.initialize();
  const runner = AppDataSource.createQueryRunner();
  await runner.connect();
  await runner.startTransaction();
  try {
    for (const fileName of migrationFiles) {
      const migrationPath = resolve(process.cwd(), 'database', fileName);
      const migration = (await readFile(migrationPath, 'utf8'))
        .replace(/^\s*BEGIN;\s*/i, '')
        .replace(/\s*COMMIT;\s*$/i, '');
      await runner.query(migration);
    }
    const rows = await runner.query(`
      SELECT
        column_name,
        data_type,
        is_nullable
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'ai_knowledge_documents'
      ORDER BY ordinal_position
    `);
    if (rows.length !== 9) {
      throw new Error(`Schema migration không đủ cột: nhận ${rows.length}, cần 9`);
    }
    const closingConstraint = await runner.query(`
      SELECT pg_get_constraintdef(oid) AS definition
      FROM pg_constraint
      WHERE conrelid = 'public.daily_closings'::regclass
        AND conname = 'UQ_daily_closings_shop_date'
    `);
    if (
      closingConstraint.length !== 1 ||
      !String(closingConstraint[0].definition).includes('shop_id, closing_date')
    ) {
      throw new Error('Migration chốt quỹ chưa tạo unique theo cửa hàng và ngày');
    }
    await runner.rollbackTransaction();
    console.log('Migration hợp lệ; toàn bộ thay đổi thử nghiệm đã rollback.');
  } catch (error) {
    await runner.rollbackTransaction();
    throw error;
  } finally {
    await runner.release();
    await AppDataSource.destroy();
  }
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
