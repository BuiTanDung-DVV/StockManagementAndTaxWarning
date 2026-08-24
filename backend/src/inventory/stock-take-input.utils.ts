export class StockTakeInputError extends Error {}

export type StockTakeItemInput = {
    productId: number;
    actualQty: number;
    notes: string | null;
};

function positiveId(value: unknown, label: string) {
    const parsed = Number(value);
    if (!Number.isSafeInteger(parsed) || parsed <= 0) throw new StockTakeInputError(`${label} không hợp lệ`);
    return parsed;
}

function quantity(value: unknown, label: string) {
    const parsed = Number(value);
    if (!Number.isSafeInteger(parsed) || parsed < 0) throw new StockTakeInputError(`${label} phải là số nguyên không âm`);
    return parsed;
}

function optionalText(value: unknown, label: string, max: number) {
    if (value === null || value === undefined || String(value).trim() === '') return null;
    const normalized = String(value).trim();
    if (normalized.length > max) throw new StockTakeInputError(`${label} không được vượt quá ${max} ký tự`);
    return normalized;
}

export function normalizeStockTakeCreateInput(input: unknown) {
    if (!input || typeof input !== 'object' || Array.isArray(input)) throw new StockTakeInputError('Dữ liệu kiểm kê không hợp lệ');
    const raw = input as Record<string, unknown>;
    const allowed = new Set(['warehouseId', 'stockTakeDate', 'takeDate', 'notes', 'items']);
    const unknown = Object.keys(raw).filter((key) => !allowed.has(key));
    if (unknown.length) throw new StockTakeInputError(`Trường kiểm kê không được phép: ${unknown.join(', ')}`);

    const dateValue = raw.stockTakeDate ?? raw.takeDate;
    const date = String(dateValue || '').trim();
    if (!/^\d{4}-\d{2}-\d{2}(?:T.*)?$/.test(date) || Number.isNaN(Date.parse(date.length === 10 ? `${date}T00:00:00Z` : date))) {
        throw new StockTakeInputError('Ngày kiểm kê không hợp lệ');
    }
    if (!Array.isArray(raw.items) || raw.items.length === 0 || raw.items.length > 500) {
        throw new StockTakeInputError('Phiếu kiểm kê phải có từ 1 đến 500 sản phẩm');
    }
    const items: StockTakeItemInput[] = raw.items.map((item, index) => {
        if (!item || typeof item !== 'object' || Array.isArray(item)) throw new StockTakeInputError(`Dòng kiểm kê ${index + 1} không hợp lệ`);
        const row = item as Record<string, unknown>;
        const rowAllowed = new Set(['productId', 'actualQty', 'notes']);
        const rowUnknown = Object.keys(row).filter((key) => !rowAllowed.has(key));
        if (rowUnknown.length) throw new StockTakeInputError(`Dòng ${index + 1} có trường không được phép: ${rowUnknown.join(', ')}`);
        return {
            productId: positiveId(row.productId, `Sản phẩm dòng ${index + 1}`),
            actualQty: quantity(row.actualQty, `Số lượng thực tế dòng ${index + 1}`),
            notes: optionalText(row.notes, `Ghi chú dòng ${index + 1}`, 200),
        };
    });
    if (new Set(items.map((item) => item.productId)).size !== items.length) {
        throw new StockTakeInputError('Một sản phẩm không được xuất hiện nhiều lần trong cùng phiếu');
    }
    return {
        warehouseId: raw.warehouseId === null || raw.warehouseId === undefined
            ? null
            : positiveId(raw.warehouseId, 'Kho'),
        stockTakeDate: date.slice(0, 10),
        notes: optionalText(raw.notes, 'Ghi chú', 500),
        items,
    };
}

export function normalizeStockTakeStatusInput(input: unknown) {
    if (!input || typeof input !== 'object' || Array.isArray(input)) throw new StockTakeInputError('Dữ liệu trạng thái không hợp lệ');
    const raw = input as Record<string, unknown>;
    const unknown = Object.keys(raw).filter((key) => !['status', 'notes'].includes(key));
    if (unknown.length) throw new StockTakeInputError(`Trường cập nhật không được phép: ${unknown.join(', ')}`);
    const status = String(raw.status || '').trim().toUpperCase();
    if (!['COMPLETED', 'CANCELLED'].includes(status)) throw new StockTakeInputError('Trạng thái kiểm kê không hợp lệ');
    return { status, notes: optionalText(raw.notes, 'Ghi chú', 500) };
}
