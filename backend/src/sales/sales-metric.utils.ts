const SALES_STATUSES = new Set([
    'PENDING',
    'CONFIRMED',
    'DELIVERED',
    'COMPLETED',
    'CANCELLED',
]);

export const normalizeSalesStatusFilter = (status?: string): string[] | undefined => {
    if (!status?.trim()) return undefined;

    const normalized = status.trim().toUpperCase();
    if (!SALES_STATUSES.has(normalized)) {
        throw new Error('Validation: Invalid sales order status');
    }

    // Dữ liệu cũ dùng COMPLETED, trong khi luồng POS hiện tại dùng DELIVERED.
    return normalized === 'COMPLETED'
        ? ['COMPLETED', 'DELIVERED']
        : [normalized];
};

export const calculateNetAmount = (income: number, expense: number): number =>
    Number(income || 0) - Number(expense || 0);

export const calculateGrossMarginPercentage = (
    netRevenue: number,
    grossProfit: number,
): number => {
    const revenue = Number(netRevenue);
    const profit = Number(grossProfit);
    if (!Number.isFinite(revenue) || revenue <= 0 || !Number.isFinite(profit)) {
        return 0;
    }
    return Math.round((profit / revenue) * 10000) / 100;
};

export type RevenueGrowthStatus =
    | 'NOT_REQUESTED'
    | 'NEW'
    | 'NO_BASE'
    | 'COMPARABLE';

export const calculateRevenueGrowth = (
    currentRevenue: number,
    previousRevenue: number | null,
    comparisonRequested: boolean,
): { growthPct: number | null; growthStatus: RevenueGrowthStatus } => {
    if (!comparisonRequested) {
        return { growthPct: null, growthStatus: 'NOT_REQUESTED' };
    }

    const current = Number(currentRevenue);
    if (!Number.isFinite(current) || current < 0) {
        throw new Error('Validation: Invalid current product revenue');
    }
    if (previousRevenue === null) {
        return { growthPct: null, growthStatus: 'NEW' };
    }

    const previous = Number(previousRevenue);
    if (!Number.isFinite(previous) || previous <= 0) {
        return { growthPct: null, growthStatus: 'NO_BASE' };
    }

    return {
        growthPct: Math.round(((current - previous) / previous) * 10000) / 100,
        growthStatus: 'COMPARABLE',
    };
};
