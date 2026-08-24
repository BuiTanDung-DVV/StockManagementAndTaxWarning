export type DebtAgingBucket = 'current' | 'past30' | 'past60' | 'past90';

const DAY_MS = 24 * 60 * 60 * 1000;

export interface DebtAgingClassification {
    bucket: DebtAgingBucket;
    daysOverdue: number;
}

export const classifyDebtAging = (
    dueDate: Date | string,
    asOf: Date,
): DebtAgingClassification => {
    const due = new Date(dueDate);
    if (Number.isNaN(due.getTime()) || Number.isNaN(asOf.getTime())) {
        throw new Error('Invalid debt aging date');
    }

    const daysOverdue = Math.max(
        Math.floor((asOf.getTime() - due.getTime()) / DAY_MS),
        0,
    );
    if (daysOverdue === 0) return { bucket: 'current', daysOverdue };
    if (daysOverdue <= 30) return { bucket: 'past30', daysOverdue };
    if (daysOverdue <= 60) return { bucket: 'past60', daysOverdue };
    return { bucket: 'past90', daysOverdue };
};
