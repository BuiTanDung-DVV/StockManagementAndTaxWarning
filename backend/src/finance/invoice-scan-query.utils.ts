import { resolveCurrentMonthExpensePeriod } from './finance-period.utils';

export class InvoiceScanQueryError extends Error {}

export function normalizeInvoiceScanQuery(input: {
    page?: unknown; limit?: unknown; search?: unknown; status?: unknown; from?: unknown; to?: unknown;
}) {
    const integer = (value: unknown, fallback: number) => {
        if (value === undefined || value === '') return fallback;
        const n = Number(value);
        if (!Number.isSafeInteger(n) || n < 1) throw new InvoiceScanQueryError('Phân trang không hợp lệ');
        return n;
    };
    const page = integer(input.page, 1), limit = Math.min(100, integer(input.limit, 12));
    const text = (value: unknown) => {
        if (value === undefined) return '';
        if (typeof value !== 'string') throw new InvoiceScanQueryError('Bộ lọc không hợp lệ');
        return value.trim();
    };
    const search = text(input.search), status = text(input.status).toUpperCase();
    if (search.length > 120) throw new InvoiceScanQueryError('Từ khóa tối đa 120 ký tự');
    if (status && !['PENDING', 'PROCESSING', 'REVIEW_REQUIRED', 'MANUAL_REQUIRED', 'CONFIRMED'].includes(status)) {
        throw new InvoiceScanQueryError('Trạng thái phiếu quét không hợp lệ');
    }
    const from = text(input.from), to = text(input.to);
    if (Boolean(from) !== Boolean(to)) throw new InvoiceScanQueryError('Chọn đủ ngày bắt đầu và kết thúc');
    let period;
    if (from && to) {
        try { period = resolveCurrentMonthExpensePeriod(from, to); }
        catch { throw new InvoiceScanQueryError('Khoảng ngày quét không hợp lệ'); }
    }
    return { page, limit, search, status, period };
}
