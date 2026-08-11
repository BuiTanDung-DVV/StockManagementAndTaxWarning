export type PayableAgingBucket = 'current' | 'past30' | 'past60' | 'past90';

const DAY_MS = 24 * 60 * 60 * 1000;

export function calculateRemainingPayable(amount: unknown, paidAmount: unknown): number {
    const total = Number(amount);
    const paid = Number(paidAmount);
    if (!Number.isFinite(total) || !Number.isFinite(paid)) return 0;
    return Math.max(total - paid, 0);
}

export function payableDaysOverdue(dueDate: Date | string, asOf: Date): number {
    const due = new Date(dueDate);
    if (Number.isNaN(due.getTime()) || Number.isNaN(asOf.getTime())) {
        throw new Error('Invalid payable aging date');
    }
    return Math.max(Math.floor((asOf.getTime() - due.getTime()) / DAY_MS), 0);
}

export function classifyPayableAging(
    dueDate: Date | string,
    asOf: Date,
): PayableAgingBucket {
    const due = new Date(dueDate);
    if (Number.isNaN(due.getTime()) || Number.isNaN(asOf.getTime())) {
        throw new Error('Invalid payable aging date');
    }
    const days = Math.floor((asOf.getTime() - due.getTime()) / DAY_MS);
    if (days <= 0) return 'current';
    if (days <= 30) return 'past30';
    if (days <= 60) return 'past60';
    return 'past90';
}
