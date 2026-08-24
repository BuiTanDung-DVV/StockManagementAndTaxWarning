import 'reflect-metadata';
import { AppDataSource } from '../config/db.config';

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
        const [readiness] = await AppDataSource.query(`
            WITH scoped_invoices AS (
                SELECT i.*
                FROM invoices i
                WHERE i.shop_id = ANY($1::int[])
            ), missing_items AS (
                SELECT i.*
                FROM scoped_invoices i
                WHERE NOT EXISTS (
                    SELECT 1 FROM invoice_items item WHERE item.invoice_id = i.id
                )
            ), missing_item_sources AS (
                SELECT
                    i.id,
                    i.reference_type,
                    i.reference_id,
                    i.subtotal AS invoice_subtotal,
                    COUNT(poi.id) FILTER (WHERE poi.quantity > 0)::int
                        AS source_item_count,
                    COUNT(poi.id) FILTER (WHERE poi.quantity <= 0)::int
                        AS zero_quantity_source_items,
                    COALESCE(SUM(poi.subtotal) FILTER (WHERE poi.quantity > 0), 0)
                        AS source_subtotal
                FROM missing_items i
                LEFT JOIN purchase_orders po
                  ON i.reference_type = 'PURCHASE_ORDER'
                 AND po.id = i.reference_id
                 AND po.shop_id = i.shop_id
                LEFT JOIN purchase_order_items poi ON poi.order_id = po.id
                GROUP BY i.id, i.reference_type, i.reference_id, i.subtotal
            ), discounted_sales AS (
                SELECT
                    i.id,
                    i.subtotal AS invoice_subtotal,
                    so.subtotal AS source_subtotal,
                    so.discount_amount,
                    COALESCE(SUM(item.subtotal), 0) AS item_subtotal
                FROM scoped_invoices i
                JOIN sales_orders so
                  ON i.reference_type = 'SALES_ORDER'
                 AND so.id = i.reference_id
                 AND so.shop_id = i.shop_id
                LEFT JOIN invoice_items item ON item.invoice_id = i.id
                WHERE so.discount_amount > 0
                GROUP BY i.id, i.subtotal, so.subtotal, so.discount_amount
            )
            SELECT
                (SELECT COUNT(*) FROM missing_items)::int AS "missingItemInvoices",
                (SELECT COUNT(*) FROM missing_item_sources
                  WHERE reference_type <> 'PURCHASE_ORDER'
                     OR reference_id IS NULL)::int AS "missingUnsupportedSource",
                (SELECT COUNT(*) FROM missing_item_sources
                  WHERE source_item_count = 0)::int AS "missingSourceItems",
                (SELECT COALESCE(SUM(zero_quantity_source_items), 0)
                  FROM missing_item_sources)::int AS "ignoredZeroQuantitySourceItems",
                (SELECT COUNT(*) FROM missing_item_sources
                  WHERE ABS(invoice_subtotal - source_subtotal) > 0.01)::int
                    AS "missingSourceSubtotalMismatch",
                (SELECT COUNT(*) FROM discounted_sales)::int AS "discountedSalesInvoices",
                (SELECT COUNT(*) FROM discounted_sales
                  WHERE ABS(item_subtotal - source_subtotal) > 0.01)::int
                    AS "discountedItemSourceMismatch",
                (SELECT COUNT(*) FROM discounted_sales
                  WHERE ABS(invoice_subtotal - (source_subtotal - discount_amount)) > 0.01)::int
                    AS "discountedHeaderSourceMismatch"
        `, [shopIds]);

        console.table([{ shopIds: shopIds.join(','), ...readiness }]);
        const blockers = [
            'missingUnsupportedSource',
            'missingSourceItems',
            'missingSourceSubtotalMismatch',
            'discountedItemSourceMismatch',
            'discountedHeaderSourceMismatch',
        ];
        if (blockers.some((key) => Number(readiness[key] || 0) > 0)) {
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
