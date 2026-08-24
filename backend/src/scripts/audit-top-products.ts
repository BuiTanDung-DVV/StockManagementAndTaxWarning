import 'reflect-metadata';
import { AppDataSource } from '../config/db.config';
import { SalesService } from '../services/sales.service';

type DirectMetric = {
    id: number;
    value: number;
    quantity: number;
    cogs: number;
    grossProfit: number;
};

type ApiMetric = DirectMetric & {
    growthPct: number | null;
    growthStatus: string;
};

const argument = (name: string): string | undefined => {
    const prefix = `--${name}=`;
    return process.argv.find((value) => value.startsWith(prefix))?.slice(prefix.length);
};

const moneyDifference = (left: number, right: number): number =>
    Math.round((left - right) * 100) / 100;

async function directPeriodMetrics(
    shopId: number,
    from: string,
    to: string,
): Promise<DirectMetric[]> {
    const rows = await AppDataSource.query(`
        WITH sold_by_product AS (
            SELECT
                oi.product_id,
                SUM(
                    CASE
                      WHEN COALESCE(o.subtotal, 0) <= 0 THEN 0
                      ELSE oi.subtotal * GREATEST(
                        0,
                        1 - COALESCE(o.discount_amount, 0) / o.subtotal
                      )
                    END
                ) AS sold_value,
                SUM(oi.quantity) AS sold_quantity,
                SUM(oi.quantity * oi.cost_price) AS sold_cogs
            FROM sales_order_items oi
            JOIN sales_orders o ON o.id = oi.order_id
            WHERE o.shop_id = $1
              AND o.order_date >= $2::date
              AND o.order_date < ($3::date + interval '1 day')
              AND o.status != 'CANCELLED'
            GROUP BY oi.product_id
        ), sold_unit_cost AS (
            SELECT
                oi.order_id,
                oi.product_id,
                COALESCE(
                    SUM(oi.quantity * oi.cost_price) / NULLIF(SUM(oi.quantity), 0),
                    0
                ) AS unit_cost
            FROM sales_order_items oi
            GROUP BY oi.order_id, oi.product_id
        ), returned_by_product AS (
            SELECT
                ri.product_id,
                SUM(
                    CASE
                      WHEN COALESCE(o.subtotal, 0) <= 0 THEN 0
                      ELSE ri.subtotal * GREATEST(
                        0,
                        1 - COALESCE(o.discount_amount, 0) / o.subtotal
                      )
                    END
                ) AS returned_value,
                SUM(ri.quantity) AS returned_quantity,
                SUM(ri.quantity * sold_unit_cost.unit_cost) AS returned_cogs
            FROM sales_return_items ri
            JOIN sales_returns r ON r.id = ri.return_id
            JOIN sales_orders o ON o.id = r.order_id
            JOIN sold_unit_cost
              ON sold_unit_cost.order_id = r.order_id
             AND sold_unit_cost.product_id = ri.product_id
            WHERE r.shop_id = $1
              AND r.return_date >= $2::date
              AND r.return_date < ($3::date + interval '1 day')
              AND UPPER(COALESCE(r.status, '')) NOT IN ('CANCELLED', 'REJECTED')
            GROUP BY ri.product_id
        )
        SELECT
            sold_by_product.product_id AS id,
            GREATEST(
                sold_by_product.sold_value - COALESCE(returned_by_product.returned_value, 0),
                0
            ) AS value,
            GREATEST(
                sold_by_product.sold_quantity - COALESCE(returned_by_product.returned_quantity, 0),
                0
            ) AS quantity,
            GREATEST(
                sold_by_product.sold_cogs - COALESCE(returned_by_product.returned_cogs, 0),
                0
            ) AS cogs,
            (sold_by_product.sold_value - COALESCE(returned_by_product.returned_value, 0)) -
            (sold_by_product.sold_cogs - COALESCE(returned_by_product.returned_cogs, 0)) AS gross_profit
        FROM sold_by_product
        LEFT JOIN returned_by_product
          ON returned_by_product.product_id = sold_by_product.product_id
        WHERE sold_by_product.sold_value - COALESCE(returned_by_product.returned_value, 0) > 0
        ORDER BY value DESC, quantity DESC, id ASC
    `, [shopId, from, to]);

    return rows.map((row: Record<string, unknown>) => ({
        id: Number(row.id),
        value: Number(row.value),
        quantity: Number(row.quantity),
        cogs: Number(row.cogs),
        grossProfit: Number(row.gross_profit),
    }));
}

async function main(): Promise<void> {
    const shopIds = (argument('shop-ids') || '')
        .split(',')
        .map((value) => Number(value.trim()))
        .filter((value) => Number.isSafeInteger(value) && value > 0);
    const from = argument('from');
    const to = argument('to');
    const previousFrom = argument('previous-from');
    const previousTo = argument('previous-to');
    if (!shopIds.length || !from || !to || !previousFrom || !previousTo) {
        throw new Error(
            'Usage: --shop-ids=<id,id> --from=YYYY-MM-DD --to=YYYY-MM-DD --previous-from=YYYY-MM-DD --previous-to=YYYY-MM-DD',
        );
    }

    await AppDataSource.initialize();
    try {
        const service = new SalesService();
        const auditRows = [];
        for (const shopId of shopIds) {
            const [rawApiRows, directAllRows, previousRows] = await Promise.all([
                service.getTopProducts(
                    shopId,
                    from,
                    to,
                    previousFrom,
                    previousTo,
                ),
                directPeriodMetrics(shopId, from, to),
                directPeriodMetrics(shopId, previousFrom, previousTo),
            ]);
            const apiRows = rawApiRows as ApiMetric[];
            const directRows = directAllRows.slice(0, 10);
            const previousById = new Map(
                previousRows.map((row) => [row.id, row.value]),
            );
            let rankMismatch = 0;
            let metricMismatch = 0;
            let growthMismatch = 0;

            apiRows.forEach((apiRow, index) => {
                const direct = directRows[index];
                if (!direct || direct.id !== apiRow.id) rankMismatch += 1;
                if (
                    !direct
                    || moneyDifference(apiRow.value, direct.value) !== 0
                    || moneyDifference(apiRow.quantity, direct.quantity) !== 0
                    || moneyDifference(apiRow.cogs, direct.cogs) !== 0
                    || moneyDifference(apiRow.grossProfit, direct.grossProfit) !== 0
                ) {
                    metricMismatch += 1;
                }

                const previous = previousById.get(apiRow.id);
                const expectedStatus = previous === undefined
                    ? 'NEW'
                    : previous <= 0
                    ? 'NO_BASE'
                    : 'COMPARABLE';
                const expectedGrowth = previous && previous > 0
                    ? Math.round(((apiRow.value - previous) / previous) * 10000) / 100
                    : null;
                if (
                    apiRow.growthStatus !== expectedStatus
                    || apiRow.growthPct !== expectedGrowth
                ) {
                    growthMismatch += 1;
                }
            });

            auditRows.push({
                shopId,
                apiRows: apiRows.length,
                directRows: directRows.length,
                rankMismatch,
                metricMismatch,
                growthMismatch,
            });
        }

        console.table(auditRows);
        if (auditRows.some((row) =>
            row.apiRows !== row.directRows
            || row.rankMismatch > 0
            || row.metricMismatch > 0
            || row.growthMismatch > 0
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
