import 'reflect-metadata';
import fs from 'node:fs';
import path from 'node:path';
import { AppDataSource } from '../config/db.config';

const CONFIRMATION = 'RESET_PENDING_OTP_20260801';

type SchemaState = {
  ready: boolean;
  pendingOtpCount: number;
};

async function schemaState(): Promise<SchemaState> {
  const [row] = await AppDataSource.query(`
    SELECT
      (
        TO_REGCLASS('public.refresh_sessions') IS NOT NULL
        AND EXISTS (
          SELECT 1 FROM information_schema.columns
          WHERE table_schema = 'public'
            AND table_name = 'users'
            AND column_name = 'auth_version'
        )
        AND EXISTS (
          SELECT 1 FROM information_schema.columns
          WHERE table_schema = 'public'
            AND table_name = 'otps'
            AND column_name = 'purpose'
        )
      ) AS ready,
      (SELECT COUNT(*)::int FROM public.otps) AS "pendingOtpCount"
  `);
  return {
    ready: row?.ready === true,
    pendingOtpCount: Number(row?.pendingOtpCount || 0),
  };
}

async function main(): Promise<void> {
  await AppDataSource.initialize();
  try {
    const before = await schemaState();
    if (before.ready) {
      console.log('Auth schema đã sẵn sàng; không chạy lại migration.');
      return;
    }
    if (process.env.CONFIRM_AUTH_MIGRATION !== CONFIRMATION) {
      throw new Error(
        `Migration chưa được xác nhận. Có ${before.pendingOtpCount} OTP sẽ bị hủy.`,
      );
    }

    const migrationPath = path.resolve(
      process.cwd(),
      'database',
      '20260801_harden_authentication.sql',
    );
    const sql = fs.readFileSync(migrationPath, 'utf8');
    await AppDataSource.query(sql);

    const after = await schemaState();
    if (!after.ready) {
      throw new Error('Migration hoàn tất nhưng schema auth chưa đạt yêu cầu');
    }
    console.log('Migration auth hoàn tất và đã được xác minh.');
  } finally {
    await AppDataSource.destroy();
  }
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
