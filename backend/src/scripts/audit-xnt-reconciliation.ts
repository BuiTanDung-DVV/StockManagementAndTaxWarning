import 'reflect-metadata';
import { AppDataSource } from '../config/db.config';
import { InventoryService } from '../services/inventory.service';

const argument = (name: string): string | undefined => {
    const prefix = `--${name}=`;
    return process.argv.find((value) => value.startsWith(prefix))?.slice(prefix.length);
};

async function main(): Promise<void> {
    const shopIds = (argument('shop-ids') || '')
        .split(',')
        .map((value) => Number(value.trim()))
        .filter((value) => Number.isSafeInteger(value) && value > 0);
    const from = argument('from');
    const to = argument('to');
    if (!shopIds.length || !from || !to) {
        throw new Error('Usage: --shop-ids=<id,id> --from=YYYY-MM-DD --to=YYYY-MM-DD');
    }

    await AppDataSource.initialize();
    try {
        const service = new InventoryService();
        const results = [];
        for (const shopId of shopIds) {
            const report = await service.getXntReport(shopId, from, to);
            const [movement] = await AppDataSource.query(`
                SELECT
                    COALESCE(SUM(CASE WHEN movement_type IN ('IN', 'RETURN') THEN quantity ELSE 0 END), 0) AS imported,
                    COALESCE(SUM(CASE WHEN movement_type = 'OUT' THEN quantity ELSE 0 END), 0) AS exported,
                    COUNT(*) AS rows
                FROM inventory_movements
                WHERE shop_id = $1
                  AND created_at >= $2::date
                  AND created_at < ($3::date + interval '1 day')
            `, [shopId, from, to]);
            const [latestMovement] = await AppDataSource.query(`
                SELECT MAX(created_at)::date::text AS "latestDate"
                FROM inventory_movements
                WHERE shop_id = $1
            `, [shopId]);
            const currentStocks = await AppDataSource.query(`
                SELECT product_id AS "productId", COALESCE(SUM(quantity), 0) AS quantity
                FROM inventory_stocks
                WHERE shop_id = $1
                GROUP BY product_id
            `, [shopId]);
            const currentStockByProduct = new Map<number, number>(
                currentStocks.map((row: { productId: string | number; quantity: string | number }) => [
                    Number(row.productId),
                    Number(row.quantity || 0),
                ]),
            );
            const reportImport = report.items.reduce(
                (sum, item) => sum + Number(item.totalImport || 0),
                0,
            );
            const reportExport = report.items.reduce(
                (sum, item) => sum + Number(item.totalExport || 0),
                0,
            );
            const equationMismatchCount = report.items.filter(
                (item) => Number(item.openingStock || 0) +
                    Number(item.totalImport || 0) -
                    Number(item.totalExport || 0) !== Number(item.closingStock || 0),
            ).length;
            const latestDate = latestMovement?.latestDate?.toString() || null;
            const snapshotComparable = latestDate !== null && to >= latestDate;
            const snapshotMismatchCount = snapshotComparable
                ? report.items.filter(
                    (item) => Number(item.closingStock || 0) !==
                        (currentStockByProduct.get(Number(item.id)) || 0),
                ).length
                : null;
            results.push({
                shopId,
                movementRows: Number(movement?.rows || 0),
                reportImport,
                databaseImport: Number(movement?.imported || 0),
                importDifference: reportImport - Number(movement?.imported || 0),
                reportExport,
                databaseExport: Number(movement?.exported || 0),
                exportDifference: reportExport - Number(movement?.exported || 0),
                equationMismatchCount,
                latestMovementDate: latestDate,
                snapshotMismatchCount,
            });
        }

        console.table(results);
        if (results.some((row) =>
            row.importDifference !== 0 ||
            row.exportDifference !== 0 ||
            row.equationMismatchCount !== 0 ||
            (row.snapshotMismatchCount !== null && row.snapshotMismatchCount !== 0)
        )) {
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
