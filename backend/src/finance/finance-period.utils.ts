export type CashTransactionQueryInput = {
    page?: number;
    limit?: number;
    type?: string;
    category?: string;
    from?: string;
    to?: string;
};

export type NormalizedCashTransactionQuery = {
    page: number;
    limit: number;
    type?: string;
    category?: string;
    fromDate?: Date;
    toDate?: Date;
};

const DATE_ONLY_PATTERN = /^\d{4}-\d{2}-\d{2}$/;
const VIETNAM_OFFSET = '+07:00';

const parseDate = (
    value: string,
    field: 'from' | 'to',
    endOfDay = false,
) => {
    const normalized = value.trim();
    const parsed = DATE_ONLY_PATTERN.test(normalized)
        ? new Date(
            `${normalized}T${endOfDay ? '23:59:59.999' : '00:00:00.000'}${VIETNAM_OFFSET}`,
        )
        : new Date(normalized);
    if (Number.isNaN(parsed.getTime())) {
        throw new Error(`Invalid ${field} date`);
    }
    return parsed;
};

const vietnamDate = (date: Date) => {
    const parts = new Intl.DateTimeFormat('en-CA', {
        timeZone: 'Asia/Ho_Chi_Minh',
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
    }).formatToParts(date);
    const value = (type: 'year' | 'month' | 'day') =>
        parts.find((part) => part.type === type)?.value;
    return `${value('year')}-${value('month')}-${value('day')}`;
};

export const normalizeCashTransactionQuery = (
    input: CashTransactionQueryInput,
): NormalizedCashTransactionQuery => {
    const page = Math.max(1, Math.trunc(input.page || 1));
    const limit = Math.min(100, Math.max(1, Math.trunc(input.limit || 20)));
    const type = input.type?.trim() || undefined;
    const category = input.category?.trim() || undefined;
    const fromDate = input.from ? parseDate(input.from, 'from') : undefined;
    const toDate = input.to ? parseDate(input.to, 'to', true) : undefined;
    if (fromDate && toDate && fromDate > toDate) {
        throw new Error('Invalid reporting period');
    }

    return { page, limit, type, category, fromDate, toDate };
};

export const resolveCurrentMonthExpensePeriod = (
    from?: string,
    to?: string,
    now = new Date(),
) => {
    const today = vietnamDate(now);
    const fromDate = from
        ? parseDate(from, 'from')
        : parseDate(`${today.slice(0, 8)}01`, 'from');
    const toDate = to
        ? parseDate(to, 'to', true)
        : parseDate(today, 'to', true);

    if (fromDate > toDate) {
        throw new Error('Invalid reporting period');
    }

    return { fromDate, toDate };
};
