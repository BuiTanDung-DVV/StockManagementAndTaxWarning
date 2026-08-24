import 'reflect-metadata';
import { AppDataSource } from '../config/db.config';

const argument = (name: string): string | undefined => {
    const prefix = `--${name}=`;
    return process.argv.find((value) => value.startsWith(prefix))?.slice(prefix.length);
};

const parseShopIds = (): number[] => (argument('shop-ids') || '')
    .split(',')
    .map((value) => Number(value.trim()))
    .filter((value) => Number.isSafeInteger(value) && value > 0);

async function main(): Promise<void> {
    const shopIds = parseShopIds();
    const apply = process.argv.includes('--apply');
    const rollbackRun = argument('rollback-run');
    if (!shopIds.length || (!apply && !rollbackRun)) {
        throw new Error(
            'Usage: --shop-ids=<id,id> (--apply | --rollback-run=<run-id>)',
        );
    }

    const runId = argument('run-id') || `invoice-backfill-${new Date()
        .toISOString()
        .replace(/[-:.TZ]/g, '')}`;
    await AppDataSource.initialize();
    const runner = AppDataSource.createQueryRunner();
    await runner.connect();
    await runner.startTransaction();
    try {
        await runner.query('SELECT pg_advisory_xact_lock($1)', [20260820]);
        await runner.query(`
            ALTER TABLE invoices
            ADD COLUMN IF NOT EXISTS discount_amount DECIMAL(18,2) NOT NULL DEFAULT 0
        `);
        await runner.query(`
            CREATE TABLE IF NOT EXISTS invoice_backfill_header_backup (
                run_id VARCHAR(80) NOT NULL,
                invoice_id INTEGER NOT NULL,
                shop_id INTEGER NOT NULL,
                subtotal DECIMAL(18,2) NOT NULL,
                discount_amount DECIMAL(18,2) NOT NULL,
                tax_amount DECIMAL(18,2) NOT NULL,
                total_amount DECIMAL(18,2) NOT NULL,
                backed_up_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                rolled_back_at TIMESTAMPTZ,
                PRIMARY KEY (run_id, invoice_id)
            )
        `);
        await runner.query(`
            CREATE TABLE IF NOT EXISTS invoice_backfill_inserted_items (
                run_id VARCHAR(80) NOT NULL,
                item_id INTEGER NOT NULL,
                invoice_id INTEGER NOT NULL,
                backed_up_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                rolled_back_at TIMESTAMPTZ,
                PRIMARY KEY (run_id, item_id)
            )
        `);

        if (rollbackRun) {
            const deleted = await runner.query(`
                DELETE FROM invoice_items item
                USING invoice_backfill_inserted_items backup
                WHERE backup.run_id = $1
                  AND backup.rolled_back_at IS NULL
                  AND item.id = backup.item_id
                RETURNING item.id
            `, [rollbackRun]);
            const restored = await runner.query(`
                UPDATE invoices invoice
                SET subtotal = backup.subtotal,
                    discount_amount = backup.discount_amount,
                    tax_amount = backup.tax_amount,
                    total_amount = backup.total_amount
                FROM invoice_backfill_header_backup backup
                WHERE backup.run_id = $1
                  AND backup.rolled_back_at IS NULL
                  AND invoice.id = backup.invoice_id
                  AND invoice.shop_id = ANY($2::int[])
                RETURNING invoice.id
            `, [rollbackRun, shopIds]);
            await runner.query(`
                UPDATE invoice_backfill_inserted_items
                SET rolled_back_at = NOW()
                WHERE run_id = $1 AND rolled_back_at IS NULL
            `, [rollbackRun]);
            await runner.query(`
                UPDATE invoice_backfill_header_backup
                SET rolled_back_at = NOW()
                WHERE run_id = $1
                  AND shop_id = ANY($2::int[])
                  AND rolled_back_at IS NULL
            `, [rollbackRun, shopIds]);
            await runner.commitTransaction();
            console.table([{
                rollbackRun,
                restoredInvoices: restored.length,
                deletedInsertedItems: deleted.length,
            }]);
            return;
        }

        const [existingRun] = await runner.query(`
            SELECT
                (SELECT COUNT(*) FROM invoice_backfill_header_backup
                  WHERE run_id = $1)::int
                +
                (SELECT COUNT(*) FROM invoice_backfill_inserted_items
                  WHERE run_id = $1)::int AS count
        `, [runId]);
        if (Number(existingRun.count || 0) > 0) {
            throw new Error(`Run ID đã tồn tại: ${runId}`);
        }

        await runner.query(`
            INSERT INTO invoice_backfill_header_backup (
                run_id, invoice_id, shop_id, subtotal, discount_amount,
                tax_amount, total_amount
            )
            SELECT
                $1, invoice.id, invoice.shop_id, invoice.subtotal,
                COALESCE(invoice.discount_amount, 0), invoice.tax_amount,
                invoice.total_amount
            FROM invoices invoice
            JOIN sales_orders source_order
              ON invoice.reference_type = 'SALES_ORDER'
             AND source_order.id = invoice.reference_id
             AND source_order.shop_id = invoice.shop_id
            WHERE invoice.shop_id = ANY($2::int[])
              AND source_order.discount_amount > 0
              AND (
                  ABS(invoice.subtotal - source_order.subtotal) > 0.01
                  OR ABS(
                      COALESCE(invoice.discount_amount, 0)
                      - source_order.discount_amount
                  ) > 0.01
              )
            RETURNING invoice_id
        `, [runId, shopIds]);

        await runner.query(`
            UPDATE invoices invoice
            SET subtotal = source_order.subtotal,
                discount_amount = source_order.discount_amount,
                total_amount = source_order.subtotal
                    - source_order.discount_amount
                    + invoice.tax_amount
            FROM sales_orders source_order
            WHERE invoice.reference_type = 'SALES_ORDER'
              AND source_order.id = invoice.reference_id
              AND source_order.shop_id = invoice.shop_id
              AND invoice.shop_id = ANY($1::int[])
              AND source_order.discount_amount > 0
              AND (
                  ABS(invoice.subtotal - source_order.subtotal) > 0.01
                  OR ABS(
                      COALESCE(invoice.discount_amount, 0)
                      - source_order.discount_amount
                  ) > 0.01
              )
            RETURNING invoice.id
        `, [shopIds]);

        await runner.query(`
            WITH inserted AS (
                INSERT INTO invoice_items (
                    invoice_id, product_id, item_name, unit, quantity,
                    unit_price, subtotal, tax_rate, tax_amount
                )
                SELECT
                    invoice.id,
                    source_item.product_id,
                    product.name,
                    product.unit,
                    source_item.quantity,
                    source_item.unit_price,
                    source_item.subtotal,
                    0,
                    0
                FROM invoices invoice
                JOIN purchase_orders source_order
                  ON invoice.reference_type = 'PURCHASE_ORDER'
                 AND source_order.id = invoice.reference_id
                 AND source_order.shop_id = invoice.shop_id
                JOIN purchase_order_items source_item
                  ON source_item.order_id = source_order.id
                JOIN products product
                  ON product.id = source_item.product_id
                 AND product.shop_id = invoice.shop_id
                WHERE invoice.shop_id = ANY($2::int[])
                  AND source_item.quantity > 0
                  AND NOT EXISTS (
                      SELECT 1
                      FROM invoice_items current_item
                      WHERE current_item.invoice_id = invoice.id
                  )
                RETURNING id, invoice_id
            )
            INSERT INTO invoice_backfill_inserted_items (run_id, item_id, invoice_id)
            SELECT $1, id, invoice_id FROM inserted
            RETURNING item_id
        `, [runId, shopIds]);

        const [quality] = await runner.query(`
            SELECT
                COUNT(*) FILTER (
                    WHERE NOT EXISTS (
                        SELECT 1 FROM invoice_items item
                        WHERE item.invoice_id = invoice.id
                    )
                )::int AS "missingItemInvoices",
                COUNT(*) FILTER (
                    WHERE ABS(
                        invoice.total_amount - (
                            invoice.subtotal
                            - COALESCE(invoice.discount_amount, 0)
                            + invoice.tax_amount
                        )
                    ) > 0.01
                )::int AS "headerTotalMismatchInvoices",
                COUNT(*) FILTER (
                    WHERE EXISTS (
                        SELECT 1
                        FROM sales_orders source_order
                        WHERE invoice.reference_type = 'SALES_ORDER'
                          AND source_order.id = invoice.reference_id
                          AND source_order.shop_id = invoice.shop_id
                          AND ABS(
                              COALESCE(invoice.discount_amount, 0)
                              - source_order.discount_amount
                          ) > 0.01
                    )
                )::int AS "discountMismatchInvoices",
                COUNT(*) FILTER (
                    WHERE EXISTS (
                        SELECT 1
                        FROM invoice_items item
                        WHERE item.invoice_id = invoice.id
                        GROUP BY item.invoice_id
                        HAVING ABS(invoice.subtotal - SUM(item.subtotal)) > 0.01
                    )
                )::int AS "subtotalMismatchInvoices"
            FROM invoices invoice
            WHERE invoice.shop_id = ANY($1::int[])
        `, [shopIds]);
        const [invalidLines] = await runner.query(`
            SELECT COUNT(*)::int AS count
            FROM invoice_items item
            JOIN invoices invoice ON invoice.id = item.invoice_id
            WHERE invoice.shop_id = ANY($1::int[])
              AND item.quantity <= 0
        `, [shopIds]);
        quality.invalidLineItems = Number(invalidLines.count || 0);
        if (Object.values(quality).some((value) => Number(value || 0) > 0)) {
            throw new Error(`Đối soát sau backfill thất bại: ${JSON.stringify(quality)}`);
        }

        await runner.query(`
            DO $$
            BEGIN
                IF NOT EXISTS (
                    SELECT 1 FROM pg_constraint
                    WHERE conname = 'chk_invoices_discount_amount'
                ) THEN
                    ALTER TABLE invoices
                    ADD CONSTRAINT chk_invoices_discount_amount
                    CHECK (
                        discount_amount >= 0
                        AND discount_amount <= subtotal
                    );
                END IF;
            END $$
        `);
        await runner.commitTransaction();
        const [appliedCounts] = await runner.query(`
            SELECT
                (SELECT COUNT(*) FROM invoice_backfill_header_backup
                  WHERE run_id = $1)::int AS "backedUpInvoices",
                (SELECT COUNT(*) FROM invoice_backfill_inserted_items
                  WHERE run_id = $1)::int AS "insertedItems"
        `, [runId]);
        console.table([{
            runId,
            backedUpInvoices: Number(appliedCounts.backedUpInvoices || 0),
            updatedInvoices: Number(appliedCounts.backedUpInvoices || 0),
            insertedItems: Number(appliedCounts.insertedItems || 0),
            ...quality,
        }]);
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
