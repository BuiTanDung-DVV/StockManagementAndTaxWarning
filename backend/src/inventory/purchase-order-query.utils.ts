export class PurchaseOrderQueryError extends Error {}

export function normalizePurchaseOrderQuery(input: Record<string, unknown>) {
    for (const key of ['page', 'limit']) {
        const value = input[key];
        if (value !== undefined && typeof value !== 'string' && typeof value !== 'number') {
            throw new PurchaseOrderQueryError('Trang hoặc số dòng đơn nhập không hợp lệ.');
        }
    }
    const page = Number(input.page ?? 1);
    const limit = Number(input.limit ?? 20);
    if (!Number.isSafeInteger(page) || page <= 0 || !Number.isSafeInteger(limit) || limit <= 0 || limit > 500
        || !Number.isSafeInteger((page - 1) * limit)) {
        throw new PurchaseOrderQueryError('Trang hoặc số dòng đơn nhập không hợp lệ.');
    }
    if ((input.search !== undefined && typeof input.search !== 'string')
        || (input.status !== undefined && typeof input.status !== 'string')) {
        throw new PurchaseOrderQueryError('Tìm kiếm hoặc trạng thái đơn nhập không hợp lệ.');
    }
    const search = String(input.search ?? '').trim();
    const status = String(input.status ?? '').trim().toUpperCase();
    if (search.length > 200 || (status && !['PENDING', 'COMPLETED', 'CANCELLED'].includes(status))) {
        throw new PurchaseOrderQueryError('Từ khóa quá dài hoặc trạng thái đơn nhập không hợp lệ.');
    }
    return { page, limit, search, status };
}
