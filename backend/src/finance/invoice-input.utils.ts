export type InvoiceInput = {
    invoiceType?: string;
    type?: string;
    invoiceDate?: Date | string;
    partnerName?: string;
    subtotal?: number | string;
    taxAmount?: number | string;
    paymentStatus?: string;
};

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
    const taxAmount = Number(input.taxAmount ?? existing.taxAmount ?? 0);
    if (!Number.isFinite(subtotal) || subtotal <= 0) {
        throw new Error('Validation: Tiền trước thuế phải lớn hơn 0');
    }
    if (!Number.isFinite(taxAmount) || taxAmount < 0) {
        throw new Error('Validation: Tiền thuế phải là số không âm');
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
        taxAmount,
        // Authoritative formula; ignore any totalAmount supplied by a client.
        totalAmount: subtotal + taxAmount,
        paymentStatus,
    };
}
