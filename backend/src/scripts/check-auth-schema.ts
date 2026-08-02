import 'reflect-metadata';
import { AppDataSource } from '../config/db.config';

type AuthSchemaStatus = {
  refreshSessionsReady: boolean;
  authVersionReady: boolean;
  otpPurposeReady: boolean;
  pendingOtpCount: number;
};

async function main(): Promise<void> {
  await AppDataSource.initialize();
  try {
    const [status] = await AppDataSource.query(`
      SELECT
        TO_REGCLASS('public.refresh_sessions') IS NOT NULL AS "refreshSessionsReady",
        EXISTS (
          SELECT 1
          FROM information_schema.columns
          WHERE table_schema = 'public'
            AND table_name = 'users'
            AND column_name = 'auth_version'
        ) AS "authVersionReady",
        EXISTS (
          SELECT 1
          FROM information_schema.columns
          WHERE table_schema = 'public'
            AND table_name = 'otps'
            AND column_name = 'purpose'
        ) AS "otpPurposeReady",
        (SELECT COUNT(*)::int FROM public.otps) AS "pendingOtpCount"
    `) as AuthSchemaStatus[];

    console.table([status]);
    const ready = status.refreshSessionsReady
      && status.authVersionReady
      && status.otpPurposeReady;
    if (!ready) {
      throw new Error('Auth schema chưa sẵn sàng cho backend mới');
    }
  } finally {
    await AppDataSource.destroy();
  }
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
