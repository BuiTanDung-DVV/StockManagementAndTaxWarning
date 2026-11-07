import { createHash } from 'crypto';

export const syncPermissions = {
    CASH_TRANSACTION_CREATE: 'finance',
    SALES_ORDER_CREATE: 'sales',
    PURCHASE_ORDER_CREATE: 'inventory',
} as const;
export type SyncKind = keyof typeof syncPermissions;

export class SyncInputError extends Error {
    constructor(message: string, public statusCode = 400) { super(message); }
}

function canonical(value: any): any {
    if (Array.isArray(value)) return value.map(canonical);
    if (value && typeof value === 'object') {
        return Object.fromEntries(Object.keys(value).sort().map(key => [key, canonical(value[key])]));
    }
    return value;
}

export function normalizeSyncInput(body: any) {
    if (!body || typeof body !== 'object' || Array.isArray(body)
        || !Number.isSafeInteger(body.actorId) || body.actorId <= 0
        || typeof body.operationId !== 'string' || !/^[a-f0-9]{32}$/.test(body.operationId)
        || typeof body.kind !== 'string' || !Object.prototype.hasOwnProperty.call(syncPermissions, body.kind)
        || !body.payload || typeof body.payload !== 'object' || Array.isArray(body.payload)) {
        throw new SyncInputError('Thông tin đồng bộ không hợp lệ.');
    }
    const payload = body.payload;
    for (const key of ['id', 'shopId', 'userId', 'createdBy', 'referenceId', 'referenceType', 'account', 'transactionCode', 'orderCode']) {
        if (Object.prototype.hasOwnProperty.call(payload, key)) throw new SyncInputError('Thông tin cửa hàng, nguồn và mã chứng từ do máy chủ quản lý.');
    }
    if (JSON.stringify(payload).length > 100000) throw new SyncInputError('Chứng từ quá lớn để đồng bộ.');
    const kind = body.kind as SyncKind;
    const allowed: Record<SyncKind, string[]> = {
        CASH_TRANSACTION_CREATE: ['type', 'amount', 'category', 'paymentMethod', 'transactionDate', 'notes', 'description', 'counterparty'],
        SALES_ORDER_CREATE: ['orderDate', 'customerId', 'shippingCarrierId', 'shippingFee', 'shippingTaxRate', 'shippingFeePayer', 'trackingCode', 'items', 'discountAmount', 'paidAmount', 'settleInFull', 'paymentMethod', 'notes', 'invoiceNumber', 'qrPaymentRef'],
        PURCHASE_ORDER_CREATE: ['supplierId', 'warehouseId', 'orderDate', 'paymentDueDate', 'invoiceNumber', 'notes', 'items'],
    };
    if (Object.keys(payload).some(key => !allowed[kind].includes(key))) {
        throw new SyncInputError('Chứng từ chứa trường không được phép đồng bộ.');
    }
    const date = payload.transactionDate ?? payload.orderDate;
    if (typeof date !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(date)) {
        throw new SyncInputError('Cần ngày nghiệp vụ định dạng YYYY-MM-DD.');
    }
    return {
        operationId: body.operationId as string, actorId: body.actorId as number, kind, payload,
        requestHash: createHash('sha256').update(JSON.stringify(canonical({ kind, payload }))).digest('hex'),
    };
}
