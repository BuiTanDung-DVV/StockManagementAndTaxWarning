import { assertPastOrToday } from '../utils/business-date';
import { vietnamDateKey } from '../finance/finance-period.utils';
import { openingEffectCents, openingEffectValue } from '../finance/opening-balance-effects.repository';
import { normalizeSettledPaymentMethod } from './payment-ledger.utils';

export class SalesPaymentError extends Error {
    constructor(message: string, public status = 400) { super(message); }
}
export function normalizeSalesPayment(raw: unknown, now = new Date()) {
    if (!raw || typeof raw !== 'object' || Array.isArray(raw)) throw new SalesPaymentError('Dữ liệu thu tiền không hợp lệ');
    const input = raw as Record<string, unknown>;
    if (Object.keys(input).some(key => !['amount', 'method', 'notes', 'referenceCode', 'operationId', 'paymentDate', 'createdBy'].includes(key))) throw new SalesPaymentError('Có trường không được phép trong khoản thu');
    if (input.operationId !== undefined && (typeof input.operationId !== 'string' || !/^[A-Za-z0-9_-]{16,80}$/.test(input.operationId))) throw new SalesPaymentError('Mã lượt ghi nhận không hợp lệ');
    let amountCents: bigint;
    try { amountCents = openingEffectCents(input.amount); } catch { throw new SalesPaymentError('Số tiền phải có tối đa hai chữ số thập phân'); }
    if (amountCents <= 0n || amountCents > 999999999999999n) throw new SalesPaymentError('Số tiền thu ngoài giới hạn cho phép');
    const explicitDate = input.paymentDate != null;
    if (explicitDate && (typeof input.paymentDate !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(input.paymentDate))) throw new SalesPaymentError('Ngày đã thu phải có dạng YYYY-MM-DD');
    let paymentDate: Date, method: string;
    try {
        paymentDate = explicitDate ? assertPastOrToday(input.paymentDate, 'Ngày thu tiền', now) : now;
        method = normalizeSettledPaymentMethod(String(input.method || 'CASH'));
    } catch (error: any) { throw new SalesPaymentError(String(error.message).replace(/^Validation:\s*/, '')); }
    const text = (key: 'notes' | 'referenceCode', limit: number) => {
        if (input[key] != null && typeof input[key] !== 'string') throw new SalesPaymentError('Ghi chú hoặc mã tham chiếu không hợp lệ');
        const value = String(input[key] || '').trim();
        if (value.length > limit) throw new SalesPaymentError(`${key === 'notes' ? 'Ghi chú' : 'Mã tham chiếu'} không được vượt quá ${limit} ký tự`);
        return value;
    };
    return {
        operationId: input.operationId as string | undefined, amountCents, amount: openingEffectValue(amountCents), method,
        paymentDate, dateKey: explicitDate ? input.paymentDate as string : vietnamDateKey(now), explicitDate,
        notes: text('notes', 200), referenceCode: text('referenceCode', 100)
    };
}
