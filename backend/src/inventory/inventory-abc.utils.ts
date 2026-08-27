export type InventoryAbcSourceRow = {
    id: number;
    sku: string;
    name: string;
    imageUrl?: string | null;
    unit: string;
    category: string;
    revenue: number;
    quantitySold: number;
    currentStock: number;
    stockValue: number;
};

export type InventoryAbcItem = InventoryAbcSourceRow & {
    rank: number;
    grade: 'A' | 'B' | 'C';
    netRevenue: number;
    revenueShare: number;
    cumulativeShare: number;
};

const finiteNumber = (value: unknown) => {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : 0;
};

const nonNegativeNumber = (value: unknown) => Math.max(finiteNumber(value), 0);

export const classifyInventoryAbc = (rows: InventoryAbcSourceRow[]) => {
    const sorted = rows
        .map((row) => ({
            ...row,
            netRevenue: finiteNumber(row.revenue),
            // ABC shares need a non-negative contribution base. A product whose
            // returns exceed sales is disclosed separately instead of inflating
            // or reversing the cumulative Pareto curve.
            revenue: nonNegativeNumber(row.revenue),
            quantitySold: finiteNumber(row.quantitySold),
            currentStock: nonNegativeNumber(row.currentStock),
            stockValue: nonNegativeNumber(row.stockValue),
        }))
        .sort((left, right) => right.revenue - left.revenue || left.id - right.id);
    const totalRevenue = sorted.reduce((sum, row) => sum + row.netRevenue, 0);
    const classificationRevenue = sorted.reduce((sum, row) => sum + row.revenue, 0);
    const negativeReturnAdjustment = classificationRevenue - totalRevenue;
    let cumulativeRevenue = 0;

    const items: InventoryAbcItem[] = sorted.map((row, index) => {
        const share = classificationRevenue > 0
            ? row.revenue / classificationRevenue
            : 0;
        cumulativeRevenue += row.revenue;
        const cumulativeShare = classificationRevenue > 0
            ? cumulativeRevenue / classificationRevenue
            : 0;
        const grade: InventoryAbcItem['grade'] = classificationRevenue <= 0
            ? 'C'
            : index === 0 || cumulativeShare <= 0.8
                ? 'A'
                : cumulativeShare <= 0.95
                    ? 'B'
                    : 'C';

        return {
            ...row,
            rank: index + 1,
            grade,
            revenueShare: share,
            cumulativeShare,
        };
    });

    const gradeSummary = (grade: InventoryAbcItem['grade']) => {
        const gradeItems = items.filter((item) => item.grade === grade);
        const revenue = gradeItems.reduce((sum, item) => sum + item.revenue, 0);
        return {
            grade,
            skuCount: gradeItems.length,
            revenue,
            revenueShare: classificationRevenue > 0
                ? revenue / classificationRevenue
                : 0,
            stockValue: gradeItems.reduce((sum, item) => sum + item.stockValue, 0),
        };
    };

    return {
        totalRevenue,
        classificationRevenue,
        negativeReturnAdjustment,
        returnedMoreThanSoldSkuCount: items.filter((item) => item.netRevenue < 0).length,
        totalStockValue: items.reduce((sum, item) => sum + item.stockValue, 0),
        skuCount: items.length,
        grades: [gradeSummary('A'), gradeSummary('B'), gradeSummary('C')],
        items,
    };
};
