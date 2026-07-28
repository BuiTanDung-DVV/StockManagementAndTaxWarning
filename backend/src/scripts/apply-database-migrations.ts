import 'reflect-metadata';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { AppDataSource } from '../config/db.config';

const MIGRATION_FILES = [
  '20260728_create_ai_knowledge_documents.sql',
  '20260728_fix_daily_closing_multi_shop_unique.sql',
];

async function main(): Promise<void> {
  if (
    !process.argv.includes('--apply') ||
    !process.argv.includes('--confirm=MIGRATE-20260728')
  ) {
    throw new Error(
      'Cần xác nhận chính xác --apply --confirm=MIGRATE-20260728',
    );
  }

  await AppDataSource.initialize();
  const runner = AppDataSource.createQueryRunner();
  await runner.connect();
  await runner.startTransaction();
  try {
    for (const fileName of MIGRATION_FILES) {
      const migrationPath = resolve(process.cwd(), 'database', fileName);
      const migration = (await readFile(migrationPath, 'utf8'))
        .replace(/^\s*BEGIN;\s*/i, '')
        .replace(/\s*COMMIT;\s*$/i, '');
      await runner.query(migration);
    }

    const checks = await runner.query(`
      SELECT
        TO_REGCLASS('public.ai_knowledge_documents') IS NOT NULL AS "aiReady",
        EXISTS (
          SELECT 1
          FROM pg_constraint
          WHERE conrelid = 'public.daily_closings'::regclass
            AND conname = 'UQ_daily_closings_shop_date'
            AND pg_get_constraintdef(oid) LIKE '%shop_id, closing_date%'
        ) AS "closingReady"
    `);
    if (!checks[0]?.aiReady || !checks[0]?.closingReady) {
      throw new Error('Đối soát migration không đạt');
    }

    await runner.commitTransaction();
    console.log('Đã áp dụng và đối soát 2 migration production.');
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
