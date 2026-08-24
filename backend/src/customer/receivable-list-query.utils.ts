import { resolveVietnamBusinessDayEnd } from '../finance/finance-period.utils';

export type ReceivableListStatus = 'ALL' | 'OVERDUE' | 'CURRENT';
export type ReceivableListSort =
    | 'DUE_DATE_ASC'
    | 'REMAINING_DESC'
    | 'CUSTOMER_ASC';

export interface ReceivableListQueryInput {
    page?: unknown;
    limit?: unknown;
    search?: unknown;
    status?: unknown;
    sort?: unknown;
    asOf?: unknown;
}

export interface NormalizedReceivableListQuery {
    page: number;
    limit: number;
    search?: string;
    status: ReceivableListStatus;
    sort: ReceivableListSort;
    asOf: Date;
}

const integer = (value: unknown, fallback: number) => {
    const parsed = Number(value);
    return Number.isInteger(parsed) ? parsed : fallback;
};

export const normalizeReceivableListQuery = (
    input: ReceivableListQueryInput,
): NormalizedReceivableListQuery => {
    const page = Math.max(1, integer(input.page, 1));
    const limit = Math.min(100, Math.max(1, integer(input.limit, 20)));
    const search = typeof input.search === 'string'
        ? input.search.trim().replace(/\s+/g, ' ')
        : '';
    if (search.length > 100) {
        throw new Error('Validation: Search must not exceed 100 characters');
    }

    const status = String(input.status || 'ALL').trim().toUpperCase();
    if (!['ALL', 'OVERDUE', 'CURRENT'].includes(status)) {
        throw new Error('Validation: Receivable status filter is invalid');
    }
    const sort = String(input.sort || 'DUE_DATE_ASC').trim().toUpperCase();
    if (!['DUE_DATE_ASC', 'REMAINING_DESC', 'CUSTOMER_ASC'].includes(sort)) {
        throw new Error('Validation: Receivable sort is invalid');
    }

    const asOfValue = typeof input.asOf === 'string' && input.asOf.trim()
        ? input.asOf.trim()
        : undefined;
    let asOf: Date;
    try {
        asOf = resolveVietnamBusinessDayEnd(asOfValue);
    } catch {
        throw new Error('Validation: As-of date is invalid');
    }

    return {
        page,
        limit,
        search: search || undefined,
        status: status as ReceivableListStatus,
        sort: sort as ReceivableListSort,
        asOf,
    };
};
