import 'reflect-metadata';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { AppDataSource } from '../config/db.config';

async function main(): Promise<void> {
    if (
        !process.argv.includes('--apply') ||
        !process.argv.includes('--confirm=MIGRATE-PAYMENT-QR')
    ) {
        throw new Error(
            'Cần xác nhận chính xác --apply --confirm=MIGRATE-PAYMENT-QR',
        );
    }

    await AppDataSource.initialize();
    const runner = AppDataSource.createQueryRunner();
    await runner.connect();
    await runner.startTransaction();
    try {
        const before = await runner.query(
            'SELECT COUNT(*)::int AS count FROM shop_profiles',
        );
        const migrationPath = resolve(
            __dirname,
            '..',
            '..',
            'database',
            '20260907_add_payment_qr_details.sql',
        );
        const migration = (await readFile(migrationPath, 'utf8'))
            .replace(/^\s*BEGIN;\s*/i, '')
            .replace(/\s*COMMIT;\s*$/i, '');
        await runner.query(migration);

        const [check] = await runner.query(`
          SELECT
            COUNT(*) FILTER (WHERE column_name = 'qr_payment_payload')::int AS "payloadColumn",
            COUNT(*) FILTER (WHERE column_name = 'qr_payment_details')::int AS "detailsColumn"
          FROM information_schema.columns
          WHERE table_schema = 'public' AND table_name = 'shop_profiles'
        `);
        const after = await runner.query(
            'SELECT COUNT(*)::int AS count FROM shop_profiles',
        );
        if (
            check?.payloadColumn !== 1 ||
            check?.detailsColumn !== 1 ||
            before[0]?.count !== after[0]?.count
        ) {
            throw new Error('Đối soát migration QR thanh toán không đạt');
        }

        await runner.commitTransaction();
        console.log(
            `Đã thêm 2 cột QR nullable; giữ nguyên ${after[0].count} hồ sơ cửa hàng.`,
        );
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
