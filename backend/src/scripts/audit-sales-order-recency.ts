import 'reflect-metadata';
import { AppDataSource } from '../config/db.config';
import { SalesService } from '../services/sales.service';

const argument = (name: string): string | undefined => {
    const prefix = `--${name}=`;
    return process.argv.find((value) => value.startsWith(prefix))?.slice(prefix.length);
};

type ExpectedOrder = {
    id: string | number;
    order_date: Date | string;
};

async function main(): Promise<void> {
    const shopIds = (argument('shop-ids') || '')
        .split(',')
        .map((value) => Number(value.trim()))
        .filter((value) => Number.isSafeInteger(value) && value > 0);
    const limit = Math.min(Math.max(Number(argument('limit')) || 20, 1), 100);
    if (!shopIds.length) {
        throw new Error('Usage: --shop-ids=<id,id> [--limit=20]');
    }

    await AppDataSource.initialize();
    try {
        const salesService = new SalesService();
        const auditRows = [];
        for (const shopId of shopIds) {
            const [servicePage, expected] = await Promise.all([
                salesService.findAll(shopId, 1, limit),
                AppDataSource.query(
                    `SELECT id, order_date
                     FROM sales_orders
                     WHERE shop_id = $1
                     ORDER BY order_date DESC, id DESC
                     LIMIT $2`,
                    [shopId, limit],
                ) as Promise<ExpectedOrder[]>,
            ]);
            const actualIds = servicePage.items.map((item) => Number(item.id));
            const expectedIds = expected.map((item) => Number(item.id));
            const mismatchCount = expectedIds.filter(
                (id, index) => actualIds[index] !== id,
            ).length;
            auditRows.push({
                shopId,
                checkedRows: expectedIds.length,
                newestBusinessDate: expected[0]?.order_date ?? null,
                serviceFirstId: actualIds[0] ?? null,
                sqlFirstId: expectedIds[0] ?? null,
                mismatchCount,
            });
        }

        console.table(auditRows);
        if (auditRows.some((row) => row.mismatchCount !== 0)) {
            process.exitCode = 2;
        }
    } finally {
        await AppDataSource.destroy();
    }
}

main().catch((error: unknown) => {
    console.error(error instanceof Error ? error.message : error);
    process.exitCode = 1;
});
