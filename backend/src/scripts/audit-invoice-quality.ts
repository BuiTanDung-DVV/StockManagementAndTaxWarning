import 'reflect-metadata';
import { AppDataSource } from '../config/db.config';
import { FinanceService } from '../services/finance.service';

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
        const service = new FinanceService();
        const results = [];
        const issueSamples = [];
        for (const shopId of shopIds) {
            const report = await service.getInvoiceReconciliation(shopId, from, to);
            results.push({ shopId, ...report.quality });
            const samples = await AppDataSource.query(`
                SELECT
                    i.shop_id::int AS "shopId",
                    i.id::int AS "invoiceId",
                    i.reference_type AS "referenceType",
                    i.reference_id::int AS "referenceId",
                    i.subtotal::numeric AS "headerSubtotal",
                    COALESCE(i.discount_amount, 0)::numeric AS "discountAmount",
                    COALESCE(SUM(item.subtotal), 0)::numeric AS "itemSubtotal",
                    COUNT(item.id)::int AS "itemCount"
                FROM invoices i
                LEFT JOIN invoice_items item ON item.invoice_id = i.id
                WHERE i.shop_id = $1
                  AND i.invoice_date >= $2::date
                  AND i.invoice_date <= $3::date
                GROUP BY i.shop_id, i.id
                HAVING COUNT(item.id) = 0
                    OR ABS(i.subtotal - COALESCE(SUM(item.subtotal), 0)) > 0.01
                    OR ABS(
                        i.total_amount - (
                            i.subtotal - COALESCE(i.discount_amount, 0) + i.tax_amount
                        )
                    ) > 0.01
                ORDER BY i.id
                LIMIT 20
            `, [shopId, from, to]);
            issueSamples.push(...samples.map((sample: any) => ({
                ...sample,
                headerSubtotal: Number(sample.headerSubtotal),
                itemSubtotal: Number(sample.itemSubtotal),
                difference: Number(sample.headerSubtotal) - Number(sample.itemSubtotal),
            })));
        }
        console.table(results);
        if (issueSamples.length > 0) {
            console.log('Mẫu hóa đơn cần đối soát (tối đa 20 mỗi cửa hàng):');
            console.table(issueSamples);
        }
        if (results.some((row) => row.hasIssues)) process.exitCode = 2;
    } finally {
        await AppDataSource.destroy();
    }
}

main().catch((error) => {
    console.error(error instanceof Error ? error.message : error);
    process.exitCode = 1;
});
