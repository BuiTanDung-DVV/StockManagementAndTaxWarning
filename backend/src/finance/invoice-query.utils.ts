import { resolveCurrentMonthExpensePeriod } from './finance-period.utils';

export class InvoiceQueryInputError extends Error {}

export const normalizeInvoiceListQuery = (input: {
    page?: number;
    limit?: number;
    type?: string;
    from?: string;
    to?: string;
}) => {
    const page = Math.max(1, Math.trunc(Number(input.page) || 1));
    const limit = Math.min(100, Math.max(1, Math.trunc(Number(input.limit) || 20)));
    const type = input.type?.trim().toUpperCase() || undefined;
    if (type && !['IN', 'OUT'].includes(type)) {
        throw new InvoiceQueryInputError('Loại hóa đơn không hợp lệ');
    }
    if (Boolean(input.from) !== Boolean(input.to)) {
        throw new InvoiceQueryInputError('Kỳ hóa đơn phải có đủ ngày bắt đầu và kết thúc');
    }
    if (!input.from || !input.to) return { page, limit, type };

    try {
        const { fromDate, toDate } = resolveCurrentMonthExpensePeriod(
            input.from,
            input.to,
        );
        return { page, limit, type, fromDate, toDate };
    } catch {
        throw new InvoiceQueryInputError('Kỳ hóa đơn không hợp lệ');
    }
};
