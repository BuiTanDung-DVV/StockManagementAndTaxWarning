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
