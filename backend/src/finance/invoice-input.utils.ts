export type InvoiceInput = {
    invoiceType?: string;
    type?: string;
    invoiceDate?: Date | string;
    partnerName?: string;
    subtotal?: number | string;
    discountAmount?: number | string;
    taxAmount?: number | string;
    paymentStatus?: string;
};

export type InvoiceItemInput = {
    productId?: number | string | null;
    itemName?: string;
    unit?: string;
    quantity?: number | string;
    unitPrice?: number | string;
    taxRate?: number | string;
};

const roundMoney = (value: number) => Math.round(value * 100) / 100;

export function normalizeInvoiceItems(input: unknown) {
    if (!Array.isArray(input) || input.length === 0) {
        throw new Error('Validation: Hóa đơn phải có ít nhất một dòng hàng');
    }

    const items = input.map((raw, index) => {
        const item = (raw || {}) as InvoiceItemInput;
        const itemName = String(item.itemName || '').trim();
        const unit = String(item.unit || '').trim();
        const quantity = Number(item.quantity);
        const unitPrice = Number(item.unitPrice);
        const taxRate = Number(item.taxRate ?? 0);
        const rawProductId = item.productId;
        const productId = rawProductId == null || rawProductId === ''
            ? null
            : Number(rawProductId);

        if (!itemName || itemName.length > 200) {
            throw new Error(`Validation: Tên hàng ở dòng ${index + 1} là bắt buộc và tối đa 200 ký tự`);
        }
        if (!unit || unit.length > 20) {
            throw new Error(`Validation: Đơn vị ở dòng ${index + 1} là bắt buộc và tối đa 20 ký tự`);
        }
        if (!Number.isInteger(quantity) || quantity <= 0) {
            throw new Error(`Validation: Số lượng ở dòng ${index + 1} phải là số nguyên lớn hơn 0`);
        }
        if (!Number.isFinite(unitPrice) || unitPrice < 0) {
            throw new Error(`Validation: Đơn giá ở dòng ${index + 1} phải là số không âm`);
        }
        if (!Number.isFinite(taxRate) || taxRate < 0 || taxRate > 100) {
            throw new Error(`Validation: Thuế suất ở dòng ${index + 1} phải từ 0 đến 100%`);
        }
        if (productId != null && (!Number.isInteger(productId) || productId <= 0)) {
            throw new Error(`Validation: Sản phẩm ở dòng ${index + 1} không hợp lệ`);
        }

        const subtotal = roundMoney(quantity * unitPrice);
        const taxAmount = roundMoney(subtotal * taxRate / 100);
        return {
            productId,
            itemName,
            unit,
            quantity,
            unitPrice: roundMoney(unitPrice),
            subtotal,
            taxRate,
            taxAmount,
        };
    });

    const subtotal = roundMoney(items.reduce((sum, item) => sum + item.subtotal, 0));
    const taxAmount = roundMoney(items.reduce((sum, item) => sum + item.taxAmount, 0));
    return {
        items,
        subtotal,
        taxAmount,
        totalAmount: roundMoney(subtotal + taxAmount),
    };
}

export function normalizeInvoiceInput(
    input: InvoiceInput,
    existing: InvoiceInput = {},
) {
    const invoiceType = String(
        input.invoiceType ?? input.type ?? existing.invoiceType ?? '',
    ).toUpperCase();
    if (!['IN', 'OUT'].includes(invoiceType)) {
        throw new Error('Validation: Loại hóa đơn phải là đầu vào hoặc đầu ra');
    }

    const rawDate = input.invoiceDate ?? existing.invoiceDate;
    const invoiceDate = rawDate instanceof Date ? rawDate : new Date(String(rawDate || ''));
    if (Number.isNaN(invoiceDate.getTime())) {
        throw new Error('Validation: Ngày hóa đơn không hợp lệ');
    }

    const partnerName = String(
        input.partnerName ?? existing.partnerName ?? '',
    ).trim();
    if (!partnerName || partnerName.length > 200) {
        throw new Error('Validation: Tên đối tác là bắt buộc và tối đa 200 ký tự');
    }

    const subtotal = Number(input.subtotal ?? existing.subtotal ?? 0);
    const discountAmount = Number(
        input.discountAmount ?? existing.discountAmount ?? 0,
    );
    const taxAmount = Number(input.taxAmount ?? existing.taxAmount ?? 0);
    if (!Number.isFinite(subtotal) || subtotal <= 0) {
        throw new Error('Validation: Tiền trước thuế phải lớn hơn 0');
    }
    if (!Number.isFinite(taxAmount) || taxAmount < 0) {
        throw new Error('Validation: Tiền thuế phải là số không âm');
    }
    if (
        !Number.isFinite(discountAmount)
        || discountAmount < 0
        || discountAmount > subtotal
    ) {
        throw new Error('Validation: Chiết khấu phải từ 0 đến tiền trước thuế');
    }

    const paymentStatus = String(
        input.paymentStatus ?? existing.paymentStatus ?? 'UNPAID',
    ).toUpperCase();
    if (!['UNPAID', 'PARTIAL', 'PAID'].includes(paymentStatus)) {
        throw new Error('Validation: Trạng thái thanh toán không hợp lệ');
    }

    return {
        invoiceType,
        invoiceDate,
        partnerName,
        subtotal,
        discountAmount,
        taxAmount,
        // Authoritative formula; ignore any totalAmount supplied by a client.
        totalAmount: subtotal - discountAmount + taxAmount,
        paymentStatus,
    };
}
