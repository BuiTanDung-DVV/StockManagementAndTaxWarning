import 'reflect-metadata';
import { AppDataSource } from '../config/db.config';

const argument = (name: string): string | undefined => {
    const prefix = `--${name}=`;
    return process.argv.find((value) => value.startsWith(prefix))?.slice(prefix.length);
};

const daysBetween = (latest: string | null, asOf: string) => {
    if (!latest) return null;
    return Math.max(0, Math.round(
        (Date.parse(`${asOf}T00:00:00Z`) - Date.parse(`${latest}T00:00:00Z`)) /
        86400000,
    ));
};

async function main(): Promise<void> {
    const shopIds = (argument('shop-ids') || '')
        .split(',')
        .map((value) => Number(value.trim()))
        .filter((value) => Number.isSafeInteger(value) && value > 0);
    const asOf = argument('as-of');
    if (!shopIds.length || !/^\d{4}-\d{2}-\d{2}$/.test(asOf || '')) {
        throw new Error('Usage: --shop-ids=<id,id> --as-of=YYYY-MM-DD');
    }

    await AppDataSource.initialize();
    try {
        const results = [];
        for (const shopId of shopIds) {
            const [row] = await AppDataSource.query(`
                SELECT
                    (SELECT MAX(order_date)::date::text
                       FROM sales_orders
                      WHERE shop_id = $1 AND status != 'CANCELLED') AS "latestSale",
                    (SELECT MAX(transaction_date)::date::text
                       FROM cash_transactions
                      WHERE shop_id = $1) AS "latestCashTransaction",
                    (SELECT (MAX(created_at) AT TIME ZONE 'Asia/Ho_Chi_Minh')::date::text
                       FROM inventory_movements
                      WHERE shop_id = $1) AS "latestInventoryMovement",
                    (SELECT MAX(invoice_date)::date::text
                       FROM invoices
                      WHERE shop_id = $1) AS "latestInvoice"
            `, [shopId]);
            results.push({
                shopId,
                latestSale: row.latestSale || null,
                saleGapDays: daysBetween(row.latestSale || null, asOf!),
                latestCashTransaction: row.latestCashTransaction || null,
                cashGapDays: daysBetween(row.latestCashTransaction || null, asOf!),
                latestInventoryMovement: row.latestInventoryMovement || null,
                inventoryGapDays: daysBetween(row.latestInventoryMovement || null, asOf!),
                latestInvoice: row.latestInvoice || null,
                invoiceGapDays: daysBetween(row.latestInvoice || null, asOf!),
            });
        }
        console.table(results);
    } finally {
        await AppDataSource.destroy();
    }
}

main().catch((error) => {
    console.error(error instanceof Error ? error.message : error);
    process.exitCode = 1;
});
