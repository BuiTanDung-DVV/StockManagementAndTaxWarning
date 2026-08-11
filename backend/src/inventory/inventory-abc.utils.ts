export type InventoryAbcSourceRow = {
    id: number;
    sku: string;
    name: string;
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
    revenueShare: number;
    cumulativeShare: number;
};

const safeNumber = (value: unknown) => {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? Math.max(parsed, 0) : 0;
};

export const classifyInventoryAbc = (rows: InventoryAbcSourceRow[]) => {
    const sorted = rows
        .map((row) => ({
            ...row,
            revenue: safeNumber(row.revenue),
            quantitySold: safeNumber(row.quantitySold),
            currentStock: safeNumber(row.currentStock),
            stockValue: safeNumber(row.stockValue),
        }))
        .sort((left, right) => right.revenue - left.revenue || left.id - right.id);
    const totalRevenue = sorted.reduce((sum, row) => sum + row.revenue, 0);
    let cumulativeRevenue = 0;

    const items: InventoryAbcItem[] = sorted.map((row, index) => {
        const share = totalRevenue > 0 ? row.revenue / totalRevenue : 0;
        cumulativeRevenue += row.revenue;
        const cumulativeShare = totalRevenue > 0
            ? cumulativeRevenue / totalRevenue
            : 0;
        const grade: InventoryAbcItem['grade'] = totalRevenue <= 0
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
            revenueShare: totalRevenue > 0 ? revenue / totalRevenue : 0,
            stockValue: gradeItems.reduce((sum, item) => sum + item.stockValue, 0),
        };
    };

    return {
        totalRevenue,
        totalStockValue: items.reduce((sum, item) => sum + item.stockValue, 0),
        skuCount: items.length,
        grades: [gradeSummary('A'), gradeSummary('B'), gradeSummary('C')],
        items,
    };
};
