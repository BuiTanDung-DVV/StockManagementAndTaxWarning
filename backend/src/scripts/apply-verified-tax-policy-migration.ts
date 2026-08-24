import 'reflect-metadata';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

import { AppDataSource } from '../config/db.config';

async function main(): Promise<void> {
  if (
    !process.argv.includes('--apply') ||
    !process.argv.includes('--confirm=TAX-POLICY-2026')
  ) {
    throw new Error(
      'Cần xác nhận chính xác --apply --confirm=TAX-POLICY-2026',
    );
  }

  await AppDataSource.initialize();
  const runner = AppDataSource.createQueryRunner();
  await runner.connect();
  await runner.startTransaction();
  try {
    const filePath = resolve(
      process.cwd(),
      'database',
      '20260813_seed_verified_tax_policy.sql',
    );
    const migration = (await readFile(filePath, 'utf8'))
      .replace(/^\s*BEGIN;\s*/i, '')
      .replace(/\s*COMMIT;\s*$/i, '');
    await runner.query(migration);

    const [check] = await runner.query(`
      SELECT
        (SELECT config_value FROM system_configs
         WHERE shop_id IS NULL AND config_key = 'TAX_EXEMPTION_THRESHOLD'
         LIMIT 1) = '1000000000' AS "thresholdReady",
        (SELECT config_value FROM system_configs
         WHERE shop_id IS NULL AND config_key = 'TAX_POLICY_SOURCE_CODE'
         LIMIT 1) = '141/2026/NĐ-CP' AS "sourceReady",
        (SELECT COUNT(DISTINCT industry_code)::int FROM tax_rules
         WHERE effective_from <= CURRENT_TIMESTAMP
           AND (effective_to IS NULL OR effective_to >= CURRENT_TIMESTAMP)
           AND industry_code IN ('BAN_LE', 'SAN_XUAT', 'DICH_VU', 'KHAC')) = 4
          AS "rulesReady"
    `);
    if (!check?.thresholdReady || !check?.sourceReady || !check?.rulesReady) {
      throw new Error('Đối soát migration cấu hình thuế không đạt');
    }

    await runner.commitTransaction();
    console.log('Đã áp dụng và đối soát cấu hình thuế 2026 từ DB.');
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
