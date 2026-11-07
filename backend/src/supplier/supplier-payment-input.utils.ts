import { assertPastOrToday } from '../utils/business-date';
import { openingEffectCents, openingEffectValue } from '../finance/opening-balance-effects.repository';
import { normalizeSettledPaymentMethod } from '../sales/payment-ledger.utils';

export class SupplierPaymentError extends Error {
    constructor(message: string, public status = 400) { super(message); }
}
export function normalizeSupplierPayment(raw: unknown, now = new Date()) {
    if (!raw || typeof raw !== 'object' || Array.isArray(raw)) throw new SupplierPaymentError('Dữ liệu trả nợ không hợp lệ');
    const input = raw as Record<string, unknown>;
    if (Object.keys(input).some(key => !['operationId', 'amount', 'method', 'paymentDate', 'notes'].includes(key))) {
        throw new SupplierPaymentError('Có trường không được phép trong khoản trả nợ');
    }
    if (typeof input.operationId !== 'string' || !/^[A-Za-z0-9_-]{16,80}$/.test(input.operationId)) {
        throw new SupplierPaymentError('Mã lượt ghi nhận không hợp lệ');
    }
    let amountCents: bigint;
    try { amountCents = openingEffectCents(input.amount); } catch { throw new SupplierPaymentError('Số tiền phải có tối đa hai chữ số thập phân'); }
    if (amountCents <= 0n || amountCents > 999999999999999n) throw new SupplierPaymentError('Số tiền trả nợ ngoài giới hạn cho phép');
    if (typeof input.paymentDate !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(input.paymentDate)) throw new SupplierPaymentError('Cần chọn ngày đã trả tiền');
    let paymentDate: Date, method: string;
    try { paymentDate = assertPastOrToday(input.paymentDate, 'Ngày trả tiền', now); method = normalizeSettledPaymentMethod(String(input.method || 'CASH')); }
    catch (error: any) { throw new SupplierPaymentError(String(error.message).replace(/^Validation:\s*/, '')); }
    if (input.notes != null && typeof input.notes !== 'string') throw new SupplierPaymentError('Ghi chú không hợp lệ');
    const notes = String(input.notes || '').trim();
    if (notes.length > 500) throw new SupplierPaymentError('Ghi chú không được vượt quá 500 ký tự');
    return {
        operationId: input.operationId, amountCents, amount: openingEffectValue(amountCents), method,
        paymentDate, dateKey: input.paymentDate, notes
    };
}

