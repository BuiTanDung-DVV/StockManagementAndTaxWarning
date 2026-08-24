import 'reflect-metadata';
import { AppDataSource } from '../config/db.config';
import { FinanceService } from '../services/finance.service';
import { SalesService } from '../services/sales.service';

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
        throw new Error(
            'Usage: --shop-ids=<id,id> --from=YYYY-MM-DD --to=YYYY-MM-DD',
        );
    }

    await AppDataSource.initialize();
    try {
        const salesService = new SalesService();
        const financeService = new FinanceService();
        const rows = [];

        for (const shopId of shopIds) {
            const [sales, profitLoss] = await Promise.all([
                salesService.summary(shopId, from, to),
                financeService.getProfitLoss(shopId, from, to),
            ]);
            const dailyRevenue = sales.daily.reduce(
                (sum, item) => sum + Number(item.revenue || 0),
                0,
            );
            const dailyOrders = sales.daily.reduce(
                (sum, item) => sum + Number(item.orderCount || 0),
                0,
            );
            const dailyCogs = sales.daily.reduce(
                (sum, item) => sum + Number(item.cogs || 0),
                0,
            );
            const dailyGrossProfit = sales.daily.reduce(
                (sum, item) => sum + Number(item.grossProfit || 0),
                0,
            );
            rows.push({
                shopId,
                salesRevenue: sales.netSalesRevenue,
                ledgerRevenue: profitLoss.revenue,
                revenueDifference: profitLoss.revenue - sales.netSalesRevenue,
                salesCogs: sales.totalCogs,
                ledgerCogs: profitLoss.cogs,
                cogsDifference: profitLoss.cogs - sales.totalCogs,
                salesGrossProfit: sales.grossProfit,
                ledgerGrossProfit: profitLoss.grossProfit,
                grossProfitDifference:
                    profitLoss.grossProfit - sales.grossProfit,
                dailyRevenueDifference: dailyRevenue - sales.netSalesRevenue,
                dailyCogsDifference: dailyCogs - sales.totalCogs,
                dailyGrossProfitDifference:
                    dailyGrossProfit - sales.grossProfit,
                dailyOrderDifference: dailyOrders - sales.orderCount,
            });
        }

        console.table(rows);
        const failed = rows.some(
            (row) =>
                row.revenueDifference !== 0 ||
                row.cogsDifference !== 0 ||
                row.grossProfitDifference !== 0 ||
                row.dailyRevenueDifference !== 0 ||
                row.dailyCogsDifference !== 0 ||
                row.dailyGrossProfitDifference !== 0 ||
                row.dailyOrderDifference !== 0,
        );
        if (failed) process.exitCode = 2;
    } finally {
        await AppDataSource.destroy();
    }
}

main().catch((error: unknown) => {
    console.error(error instanceof Error ? error.message : error);
    process.exitCode = 1;
});
