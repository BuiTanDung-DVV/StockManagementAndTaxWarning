import 'reflect-metadata';
import { AppDataSource } from '../config/db.config';
import { SalesService } from '../services/sales.service';
import { TaxService } from '../services/tax.service';

const argument = (name: string): string | undefined => {
    const prefix = `--${name}=`;
    return process.argv.find((value) => value.startsWith(prefix))?.slice(prefix.length);
};

const difference = (left: number, right: number): number =>
    Math.round((left - right) * 100) / 100;

const lastDayOfMonth = (year: number, month: number): string => {
    const day = new Date(Date.UTC(year, month, 0)).getUTCDate();
    return `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
};

async function main(): Promise<void> {
    const shopIds = (argument('shop-ids') || '')
        .split(',')
        .map((value) => Number(value.trim()))
        .filter((value) => Number.isSafeInteger(value) && value > 0);
    const year = Number(argument('year'));
    const month = Number(argument('month'));
    if (
        !shopIds.length
        || !Number.isInteger(year)
        || year < 2000
        || !Number.isInteger(month)
        || month < 1
        || month > 12
    ) {
        throw new Error('Usage: --shop-ids=<id,id> --year=YYYY --month=1..12');
    }

    const monthKey = String(month).padStart(2, '0');
    const monthFrom = `${year}-${monthKey}-01`;
    const monthTo = lastDayOfMonth(year, month);
    const yearFrom = `${year}-01-01`;
    const yearTo = `${year}-12-31`;

    await AppDataSource.initialize();
    try {
        const salesService = new SalesService();
        const taxService = new TaxService();
        const auditRows = [];
        for (const shopId of shopIds) {
            const [taxMonthRevenue, taxYearRevenue, monthSales, yearSales] = await Promise.all([
                taxService.getRevenueBasis(shopId, monthFrom, monthTo),
                taxService.getRevenueBasis(shopId, yearFrom, yearTo),
                salesService.summary(shopId, monthFrom, monthTo),
                salesService.summary(shopId, yearFrom, yearTo),
            ]);
            auditRows.push({
                shopId,
                taxMonthRevenue,
                salesMonthRevenue: monthSales.totalRevenue,
                monthDifference: difference(
                    taxMonthRevenue,
                    monthSales.totalRevenue,
                ),
                taxYearRevenue,
                salesYearRevenue: yearSales.totalRevenue,
                yearDifference: difference(
                    taxYearRevenue,
                    yearSales.totalRevenue,
                ),
            });
        }

        console.table(auditRows);
        if (auditRows.some((row) =>
            row.monthDifference !== 0 || row.yearDifference !== 0
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
