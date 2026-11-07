import { vietnamDateKey } from '../finance/finance-period.utils';

/** Actual transactions may be backdated, but may not be dated in the future. */
export function assertPastOrToday(value: unknown, label: string, now = new Date()): Date {
    const parsed = value instanceof Date ? new Date(value) : new Date(String(value));
    const text = typeof value === 'string' ? value : '';
    const day = text.slice(0, 10);
    if (Number.isNaN(parsed.getTime()) ||
        (/^\d{4}-\d{2}-\d{2}$/.test(day) && new Date(`${day}T00:00:00Z`).toISOString().slice(0, 10) !== day)) {
        throw new Error(`Validation: ${label} không hợp lệ`);
    }
    if (vietnamDateKey(parsed) > vietnamDateKey(now)) {
        throw new Error(`Validation: ${label} chỉ được là hôm nay hoặc ngày trong quá khứ`);
    }
    return parsed;
}
