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
        for (const shopId of shopIds) {
            const [list, inputList, outputList, summary, [database]] = await Promise.all([
                service.getInvoices(shopId, 1, 20, undefined, from, to),
                service.getInvoices(shopId, 1, 20, 'IN', from, to),
                service.getInvoices(shopId, 1, 20, 'OUT', from, to),
                service.getInvoiceSummary(shopId, from, to),
                AppDataSource.query(`
                    SELECT
                        COUNT(*)::int AS total,
                        COUNT(*) FILTER (WHERE invoice_type = 'IN')::int AS inbound,
                        COUNT(*) FILTER (WHERE invoice_type = 'OUT')::int AS outbound,
                        COALESCE(SUM(tax_amount) FILTER (WHERE invoice_type = 'IN'), 0) AS "vatIn",
                        COALESCE(SUM(tax_amount) FILTER (WHERE invoice_type = 'OUT'), 0) AS "vatOut"
                    FROM invoices
                    WHERE shop_id = $1
                      AND invoice_date >= $2::date
                      AND invoice_date <= $3::date
                `, [shopId, from, to]),
            ]);
            results.push({
                shopId,
                listTotal: list.total,
                databaseTotal: Number(database.total || 0),
                totalDifference: list.total - Number(database.total || 0),
                typeCountDifference:
                    inputList.total + outputList.total - Number(database.total || 0),
                vatInDifference: Number(summary.vatIn) - Number(database.vatIn || 0),
                vatOutDifference: Number(summary.vatOut) - Number(database.vatOut || 0),
            });
        }
        console.table(results);
        if (results.some((row) =>
            row.totalDifference !== 0 ||
            row.typeCountDifference !== 0 ||
            row.vatInDifference !== 0 ||
            row.vatOutDifference !== 0
        )) process.exitCode = 2;
    } finally {
        await AppDataSource.destroy();
    }
}

main().catch((error) => {
    console.error(error instanceof Error ? error.message : error);
    process.exitCode = 1;
});
