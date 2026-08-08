import 'reflect-metadata';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { AppDataSource } from '../config/db.config';

const CONFIRMATION = 'NULLABLE_ACCOUNT_TYPE_20260809';

async function readSchemaState(): Promise<{ ready: boolean; invalidRows: number }> {
  const [row] = await AppDataSource.query(`
    SELECT
      EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'users'
          AND column_name = 'account_type'
          AND is_nullable = 'YES'
          AND column_default IS NULL
      ) AND EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.users'::regclass
          AND conname = 'users_account_type_allowed'
      ) AS ready,
      (
        SELECT COUNT(*)::int
        FROM public.users
        WHERE account_type IS NOT NULL
          AND account_type NOT IN ('SHOP', 'PERSONAL')
      ) AS "invalidRows"
  `);
  return {
    ready: row?.ready === true,
    invalidRows: Number(row?.invalidRows || 0),
  };
}

async function main(): Promise<void> {
  await AppDataSource.initialize();
  try {
    const before = await readSchemaState();
    if (before.invalidRows > 0) {
      throw new Error(`Có ${before.invalidRows} tài khoản mang account_type không hợp lệ`);
    }
    if (before.ready) {
      console.log('Schema account_type đã sẵn sàng; không chạy lại migration.');
      return;
    }
    if (process.env.CONFIRM_ACCOUNT_TYPE_MIGRATION !== CONFIRMATION) {
      throw new Error(
        'Migration chưa được xác nhận bằng CONFIRM_ACCOUNT_TYPE_MIGRATION.',
      );
    }

    const migrationPath = resolve(
      process.cwd(),
      'database',
      '20260809_nullable_account_type_until_onboarding.sql',
    );
    await AppDataSource.query(await readFile(migrationPath, 'utf8'));

    const after = await readSchemaState();
    if (!after.ready || after.invalidRows > 0) {
      throw new Error('Đối soát schema account_type sau migration không đạt');
    }
    console.log('Migration account_type hoàn tất và đã được đối soát.');
  } finally {
    await AppDataSource.destroy();
  }
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
