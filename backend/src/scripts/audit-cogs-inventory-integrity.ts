import 'reflect-metadata';
import { AppDataSource } from '../config/db.config';

const argument = (name: string): string | undefined => {
    const prefix = `--${name}=`;
    return process.argv.find((value) => value.startsWith(prefix))?.slice(prefix.length);
};

type AuditRow = {
    shopId: number;
    stockProducts: number;
    lotProducts: number;
    stockQuantity: number;
    lotQuantity: number;
    productQuantityMismatch: number;
    stockWithoutLots: number;
    lotWithoutStock: number;
    orderCogsMismatch: number;
    soldLinesWithZeroCost: number;
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
        const rows: AuditRow[] = await AppDataSource.query(`
            WITH stock AS (
                SELECT shop_id, product_id, SUM(quantity)::numeric AS quantity
                FROM inventory_stocks
                WHERE shop_id = ANY($1)
                GROUP BY shop_id, product_id
            ), lots AS (
                SELECT shop_id, product_id, SUM(remaining_qty)::numeric AS quantity
                FROM inventory_lots
                WHERE shop_id = ANY($1)
                GROUP BY shop_id, product_id
            ), product_check AS (
                SELECT
                    COALESCE(stock.shop_id, lots.shop_id) AS shop_id,
                    COALESCE(stock.product_id, lots.product_id) AS product_id,
                    stock.quantity AS stock_quantity,
                    lots.quantity AS lot_quantity
                FROM stock
                FULL OUTER JOIN lots
                  ON lots.shop_id = stock.shop_id
                 AND lots.product_id = stock.product_id
            ), item_cogs AS (
                SELECT
                    o.shop_id,
                    o.id AS order_id,
                    o.total_cogs::numeric AS order_cogs,
                    COALESCE(SUM(oi.quantity * oi.cost_price), 0)::numeric AS item_cogs,
                    COUNT(*) FILTER (
                        WHERE oi.quantity > 0 AND COALESCE(oi.cost_price, 0) <= 0
                    )::int AS zero_cost_lines
                FROM sales_orders o
                JOIN sales_order_items oi ON oi.order_id = o.id
                WHERE o.shop_id = ANY($1)
                  AND UPPER(COALESCE(o.status, '')) != 'CANCELLED'
                GROUP BY o.shop_id, o.id, o.total_cogs
            )
            SELECT
                shops.shop_id::int AS "shopId",
                COUNT(product_check.product_id) FILTER (
                    WHERE product_check.stock_quantity IS NOT NULL
                )::int AS "stockProducts",
                COUNT(product_check.product_id) FILTER (
                    WHERE product_check.lot_quantity IS NOT NULL
                )::int AS "lotProducts",
                COALESCE(SUM(product_check.stock_quantity), 0)::numeric AS "stockQuantity",
                COALESCE(SUM(product_check.lot_quantity), 0)::numeric AS "lotQuantity",
                COUNT(product_check.product_id) FILTER (
                    WHERE ABS(
                        COALESCE(product_check.stock_quantity, 0)
                        - COALESCE(product_check.lot_quantity, 0)
                    ) > 0.0001
                )::int AS "productQuantityMismatch",
                COUNT(product_check.product_id) FILTER (
                    WHERE COALESCE(product_check.stock_quantity, 0) > 0
                      AND product_check.lot_quantity IS NULL
                )::int AS "stockWithoutLots",
                COUNT(product_check.product_id) FILTER (
                    WHERE COALESCE(product_check.lot_quantity, 0) > 0
                      AND product_check.stock_quantity IS NULL
                )::int AS "lotWithoutStock",
                (
                    SELECT COUNT(*)::int
                    FROM item_cogs c
                    WHERE c.shop_id = shops.shop_id
                      AND ABS(c.order_cogs - c.item_cogs) > 0.01
                ) AS "orderCogsMismatch",
                (
                    SELECT COALESCE(SUM(c.zero_cost_lines), 0)::int
                    FROM item_cogs c
                    WHERE c.shop_id = shops.shop_id
                ) AS "soldLinesWithZeroCost"
            FROM UNNEST($1::int[]) AS shops(shop_id)
            LEFT JOIN product_check ON product_check.shop_id = shops.shop_id
            GROUP BY shops.shop_id
            ORDER BY shops.shop_id
        `, [shopIds]);

        const normalized = rows.map((row) => ({
            ...row,
            stockQuantity: Number(row.stockQuantity),
            lotQuantity: Number(row.lotQuantity),
        }));
        console.table(normalized);
        if (normalized.some((row) =>
            row.productQuantityMismatch > 0
            || row.stockWithoutLots > 0
            || row.lotWithoutStock > 0
            || row.orderCogsMismatch > 0
            || row.soldLinesWithZeroCost > 0
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
