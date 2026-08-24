import 'reflect-metadata';
import { AppDataSource } from '../config/db.config';
import { CustomerService } from '../services/customer.service';

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
    const asOf = argument('as-of') || new Date().toISOString().slice(0, 10);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(asOf)) {
        throw new Error('Invalid --as-of date. Expected YYYY-MM-DD');
    }

    await AppDataSource.initialize();
    try {
        const rows = await AppDataSource.query(`
            WITH open_receivables AS (
                SELECT
                    r.shop_id,
                    r.customer_id,
                    r.order_id,
                    r.amount::numeric AS amount,
                    r.paid_amount::numeric AS paid_amount,
                    r.due_date,
                    GREATEST(r.amount - r.paid_amount, 0)::numeric AS remaining
                FROM receivables r
                WHERE r.shop_id = ANY($1)
                  AND r.status NOT IN ('PAID', 'CANCELLED')
                  AND r.amount - r.paid_amount > 0
            ), per_shop AS (
                SELECT
                    shop_id,
                    COUNT(*)::int AS receivable_count,
                    COUNT(DISTINCT customer_id)::int AS customer_count,
                    COUNT(*) FILTER (WHERE order_id IS NULL)::int AS manual_count,
                    COUNT(*) FILTER (WHERE order_id IS NOT NULL)::int AS linked_count,
                    SUM(remaining)::numeric AS remaining,
                    SUM(paid_amount)::numeric AS paid_on_open,
                    SUM(
                        CASE WHEN due_date < $2::date THEN remaining ELSE 0 END
                    )::numeric AS overdue,
                    SUM(CASE WHEN due_date >= $2::date THEN remaining ELSE 0 END)::numeric
                        AS current_bucket,
                    SUM(CASE
                        WHEN due_date < $2::date
                         AND due_date >= $2::date - 30
                        THEN remaining ELSE 0 END)::numeric AS past_30,
                    SUM(CASE
                        WHEN due_date < $2::date - 30
                         AND due_date >= $2::date - 60
                        THEN remaining ELSE 0 END)::numeric AS past_60,
                    SUM(CASE
                        WHEN due_date < $2::date - 60
                        THEN remaining ELSE 0 END)::numeric AS past_90,
                    COUNT(*) FILTER (WHERE customer_id IS NULL)::int
                        AS orphan_customer,
                    COUNT(*) FILTER (
                        WHERE amount < 0 OR paid_amount < 0 OR paid_amount > amount
                    )::int AS invalid_amount
                FROM open_receivables
                GROUP BY shop_id
            ), customer_cache AS (
                SELECT
                    c.shop_id,
                    SUM(GREATEST(c.balance, 0))::numeric AS cached_balance
                FROM customers c
                WHERE c.shop_id = ANY($1)
                GROUP BY c.shop_id
            )
            SELECT
                p.*,
                COALESCE(c.cached_balance, 0)::numeric AS cached_balance,
                (COALESCE(c.cached_balance, 0) - p.remaining)::numeric
                    AS cache_difference
            FROM per_shop p
            LEFT JOIN customer_cache c USING (shop_id)
            ORDER BY p.shop_id
        `, [shopIds, asOf]);

        console.table(rows);
        const duplicateLinkedOrders = await AppDataSource.query(`
            SELECT shop_id, order_id, COUNT(*)::int AS receivable_count
            FROM receivables
            WHERE shop_id = ANY($1)
              AND order_id IS NOT NULL
            GROUP BY shop_id, order_id
            HAVING COUNT(*) > 1
            ORDER BY shop_id, order_id
        `, [shopIds]);
        console.table(duplicateLinkedOrders);
        if (duplicateLinkedOrders.length > 0) {
            process.exitCode = 2;
        }
        const service = new CustomerService();
        for (const shopId of shopIds) {
            const database = rows.find((row: any) => Number(row.shop_id) === shopId);
            const report = await service.getDebtAging(shopId, asOf);
            const comparisons = {
                shopId,
                asOf,
                totalDifference: Number(report.totalDebt) - Number(database?.remaining || 0),
                currentDifference: Number(report.buckets.current) - Number(database?.current_bucket || 0),
                past30Difference: Number(report.buckets.past30) - Number(database?.past_30 || 0),
                past60Difference: Number(report.buckets.past60) - Number(database?.past_60 || 0),
                past90Difference: Number(report.buckets.past90) - Number(database?.past_90 || 0),
                receivableCountDifference:
                    Number(report.receivableCount) - Number(database?.receivable_count || 0),
                customerCountDifference:
                    Number(report.customerCount) - Number(database?.customer_count || 0),
            };
            console.table([comparisons]);
            if (Object.entries(comparisons).some(([key, value]) => key.endsWith('Difference') && value !== 0)) {
                process.exitCode = 2;
            }
        }
    } finally {
        await AppDataSource.destroy();
    }
}

main().catch((error: unknown) => {
    console.error(error instanceof Error ? error.message : error);
    process.exitCode = 1;
});
