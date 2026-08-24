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
    const daysUnsold = Number(argument('days-unsold') || 30);

    if (!shopIds.length || !Number.isSafeInteger(daysUnsold) || daysUnsold <= 0) {
        throw new Error('Usage: --shop-ids=<id,id> [--days-unsold=30]');
    }

    await AppDataSource.initialize();
    try {
        const service = new InventoryService();
        const [stock, slowMoving] = await Promise.all([
            service.getStock(shopIds, 1, 1),
            service.getSlowMovingProducts(shopIds, daysUnsold),
        ]);
        const totalSlowValue = slowMoving.reduce(
            (sum, item) => sum + Number(item.stockValue || 0),
            0,
        );
        const invalidRows = slowMoving.filter(
            (item) =>
                !item.name ||
                !item.unit ||
                Number(item.currentStock) <= 0 ||
                Number(item.costPrice) < 0 ||
                Number(item.stockValue) < 0,
        );

        console.table({
            shopScope: shopIds.join(','),
            stockRows: stock.total,
            distinctProducts: stock.productTotal,
            slowMovingSku: slowMoving.length,
            slowMovingCostValue: totalSlowValue,
            invalidSlowMovingRows: invalidRows.length,
        });
        console.table(
            slowMoving.slice(0, 5).map((item) => ({
                shopId: item.shopId,
                sku: item.sku,
                name: item.name,
                unit: item.unit,
                currentStock: item.currentStock,
                stockValue: item.stockValue,
                daysSinceLastSale: item.daysSinceLastSale,
            })),
        );
    } finally {
        await AppDataSource.destroy();
    }
}

main().catch((error: unknown) => {
    console.error(error instanceof Error ? error.message : error);
    process.exitCode = 1;
});
