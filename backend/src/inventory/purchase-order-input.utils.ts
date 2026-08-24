export class PurchaseOrderInputError extends Error {}

export type PurchaseOrderItemInput = {
    productId: number;
    quantity: number;
    unitPrice: number;
};

function positiveInteger(value: unknown, label: string) {
    const parsed = Number(value);
    if (!Number.isSafeInteger(parsed) || parsed <= 0) throw new PurchaseOrderInputError(`${label} không hợp lệ`);
    return parsed;
}

function positiveNumber(value: unknown, label: string) {
    const parsed = Number(value);
    if (!Number.isFinite(parsed) || parsed <= 0 || parsed > 1_000_000_000_000_000) {
        throw new PurchaseOrderInputError(`${label} phải lớn hơn 0`);
    }
    return parsed;
}

function optionalText(value: unknown, label: string, max: number) {
    if (value === null || value === undefined || String(value).trim() === '') return null;
    const normalized = String(value).trim();
    if (normalized.length > max) throw new PurchaseOrderInputError(`${label} không được vượt quá ${max} ký tự`);
    return normalized;
}

export function normalizePurchaseOrderCreateInput(input: unknown) {
    if (!input || typeof input !== 'object' || Array.isArray(input)) throw new PurchaseOrderInputError('Dữ liệu đơn nhập không hợp lệ');
    const raw = input as Record<string, unknown>;
    const allowed = new Set(['supplierId', 'warehouseId', 'orderDate', 'paymentDueDate', 'invoiceNumber', 'notes', 'items']);
    const unknown = Object.keys(raw).filter((key) => !allowed.has(key));
    if (unknown.length) throw new PurchaseOrderInputError(`Trường đơn nhập không được phép: ${unknown.join(', ')}`);
    const orderDate = String(raw.orderDate || '').trim();
    if (!orderDate || Number.isNaN(Date.parse(orderDate))) throw new PurchaseOrderInputError('Ngày nhập hàng không hợp lệ');
    if (!Array.isArray(raw.items) || raw.items.length === 0 || raw.items.length > 500) {
        throw new PurchaseOrderInputError('Đơn nhập phải có từ 1 đến 500 sản phẩm');
    }
    const items: PurchaseOrderItemInput[] = raw.items.map((item, index) => {
        if (!item || typeof item !== 'object' || Array.isArray(item)) throw new PurchaseOrderInputError(`Dòng hàng ${index + 1} không hợp lệ`);
        const row = item as Record<string, unknown>;
        const rowUnknown = Object.keys(row).filter((key) => !['productId', 'quantity', 'unitPrice'].includes(key));
        if (rowUnknown.length) throw new PurchaseOrderInputError(`Dòng ${index + 1} có trường không được phép: ${rowUnknown.join(', ')}`);
        return {
            productId: positiveInteger(row.productId, `Sản phẩm dòng ${index + 1}`),
            quantity: positiveNumber(row.quantity, `Số lượng dòng ${index + 1}`),
            unitPrice: positiveNumber(row.unitPrice, `Giá nhập dòng ${index + 1}`),
        };
    });
    if (new Set(items.map((item) => item.productId)).size !== items.length) {
        throw new PurchaseOrderInputError('Một sản phẩm không được lặp lại trong cùng đơn nhập');
    }
    const paymentDueDate = raw.paymentDueDate === null || raw.paymentDueDate === undefined || raw.paymentDueDate === ''
        ? null
        : String(raw.paymentDueDate).slice(0, 10);
    if (paymentDueDate && Number.isNaN(Date.parse(`${paymentDueDate}T00:00:00Z`))) {
        throw new PurchaseOrderInputError('Hạn thanh toán không hợp lệ');
    }
    return {
        supplierId: positiveInteger(raw.supplierId, 'Nhà cung cấp'),
        warehouseId: raw.warehouseId === null || raw.warehouseId === undefined
            ? null
            : positiveInteger(raw.warehouseId, 'Kho'),
        orderDate: new Date(orderDate),
        paymentDueDate,
        invoiceNumber: optionalText(raw.invoiceNumber, 'Số hóa đơn', 50),
        notes: optionalText(raw.notes, 'Ghi chú', 500),
        items,
    };
}

export function normalizePurchaseOrderUpdateInput(input: unknown) {
    if (!input || typeof input !== 'object' || Array.isArray(input)) throw new PurchaseOrderInputError('Dữ liệu cập nhật đơn nhập không hợp lệ');
    const raw = input as Record<string, unknown>;
    const unknown = Object.keys(raw).filter((key) => !['status', 'warehouseId'].includes(key));
    if (unknown.length) throw new PurchaseOrderInputError(`Trường cập nhật không được phép: ${unknown.join(', ')}`);
    const status = String(raw.status || '').trim().toUpperCase();
    if (!['PENDING', 'COMPLETED', 'CANCELLED'].includes(status)) throw new PurchaseOrderInputError('Trạng thái đơn nhập không hợp lệ');
    return {
        status,
        warehouseId: raw.warehouseId === undefined
            ? undefined
            : positiveInteger(raw.warehouseId, 'Kho'),
    };
}
