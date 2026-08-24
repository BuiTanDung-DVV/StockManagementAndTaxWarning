import 'reflect-metadata';
import { AppDataSource } from '../config/db.config';
import { InventoryService } from '../services/inventory.service';

type ProductQuantity = { productId: number; quantity: number };

const argument = (name: string): string | undefined => {
    const prefix = `--${name}=`;
    return process.argv.find((value) => value.startsWith(prefix))?.slice(prefix.length);
};

async function main(): Promise<void> {
    const shopIds = (argument('shop-ids') || '')
        .split(',')
        .map((value) => Number(value.trim()))
        .filter((value) => Number.isSafeInteger(value) && value > 0);
    if (!shopIds.length) {
        throw new Error('Usage: --shop-ids=<id,id>');
    }

    await AppDataSource.initialize();
    try {
        const service = new InventoryService();
        const auditRows = [];
        for (const shopId of shopIds) {
            const [serviceRows, rawRows, aggregateRows] = await Promise.all([
                service.getLowStock(shopId),
                AppDataSource.query(`
                    SELECT s.product_id
                    FROM inventory_stocks s
                    JOIN products p ON p.id = s.product_id
                    WHERE s.shop_id = $1
                      AND s.quantity <= COALESCE(p.min_stock, 0)
                `, [shopId]),
                AppDataSource.query(`
                    SELECT
                        p.id AS product_id,
                        COALESCE(SUM(s.quantity), 0) AS quantity
                    FROM inventory_stocks s
                    JOIN products p ON p.id = s.product_id
                    WHERE s.shop_id = $1
                    GROUP BY p.id, p.min_stock
                    HAVING COALESCE(SUM(s.quantity), 0) <= COALESCE(p.min_stock, 0)
                `, [shopId]),
            ]);

            const oldProductIds = new Set<number>(
                rawRows.map((row: Record<string, unknown>) => Number(row.product_id)),
            );
            const direct = (aggregateRows as Array<Record<string, unknown>>).map(
                (row): ProductQuantity => ({
                    productId: Number(row.product_id),
                    quantity: Number(row.quantity),
                }),
            );
            const directByProduct = new Map(
                direct.map((row) => [row.productId, row.quantity]),
            );
            const serviceProductIds = new Set<number>();
            let quantityMismatch = 0;
            for (const row of serviceRows) {
                const productId = Number(row.productId);
                serviceProductIds.add(productId);
                if (Number(row.quantity) !== directByProduct.get(productId)) {
                    quantityMismatch += 1;
                }
            }
            const membershipMismatch = [
                ...serviceProductIds,
                ...directByProduct.keys(),
            ].filter(
                (productId, index, all) =>
                    all.indexOf(productId) === index
                    && serviceProductIds.has(productId) !== directByProduct.has(productId),
            ).length;

            auditRows.push({
                shopId,
                oldWarehouseRows: rawRows.length,
                oldDistinctProducts: oldProductIds.size,
                aggregateProducts: direct.length,
                serviceProducts: serviceRows.length,
                duplicateServiceProducts:
                    serviceRows.length - serviceProductIds.size,
                membershipMismatch,
                quantityMismatch,
            });
        }

        console.table(auditRows);
        if (auditRows.some((row) =>
            row.aggregateProducts !== row.serviceProducts
            || row.duplicateServiceProducts !== 0
            || row.membershipMismatch !== 0
            || row.quantityMismatch !== 0
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
