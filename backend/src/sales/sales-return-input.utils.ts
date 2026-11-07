import { assertPastOrToday } from '../utils/business-date';
import { openingEffectCents } from '../finance/opening-balance-effects.repository';
import { SalesWriteError } from './sales-write-authorization';

export function normalizeSalesReturn(raw: unknown, now = new Date()) {
    if (!raw || typeof raw !== 'object' || Array.isArray(raw)) throw new SalesWriteError('Dữ liệu trả hàng không hợp lệ');
    const input = raw as Record<string, unknown>;
    if (Object.keys(input).some(key => !['items', 'refundAmount', 'refundShippingFee', 'returnDate', 'returnCode', 'refundMethod', 'reason', 'notes', 'createdBy'].includes(key))) throw new SalesWriteError('Có trường không được phép trong phiếu trả hàng');
    if (input.refundShippingFee != null && typeof input.refundShippingFee !== 'boolean') throw new SalesWriteError('Lựa chọn hoàn phí giao hàng phải là có hoặc không');
    let refundAmountCents: bigint | undefined;
    if (input.refundAmount != null) {
        try { refundAmountCents = openingEffectCents(input.refundAmount); } catch { throw new SalesWriteError('Số tiền hoàn phải là số hợp lệ, tối đa hai chữ số thập phân'); }
        if (refundAmountCents < 0n || refundAmountCents > 999999999999999n) throw new SalesWriteError('Số tiền hoàn ngoài giới hạn cho phép');
    }
    let returnDate: Date;
    if (input.returnDate != null && !(input.returnDate instanceof Date) && (typeof input.returnDate !== 'string' || !/^\d{4}-\d{2}-\d{2}(?:T.*)?$/.test(input.returnDate))) throw new SalesWriteError('Ngày trả hàng phải có dạng YYYY-MM-DD hoặc thời điểm ISO');
    try { returnDate = assertPastOrToday(input.returnDate ?? now, 'Ngày trả hàng', now); } catch (error: any) { throw new SalesWriteError(String(error.message).replace(/^Validation:\s*/, '')); }
    const text = (key: string, max: number) => {
        if (input[key] == null) return undefined;
        if (typeof input[key] !== 'string') throw new SalesWriteError(`${key === 'reason' ? 'Lý do' : key === 'notes' ? 'Ghi chú' : 'Mã hoặc phương thức'} không hợp lệ`);
        const value = (input[key] as string).trim();
        if (value.length > max) throw new SalesWriteError(`Trường ${key} không được vượt quá ${max} ký tự`);
        return value;
    };
    if (!Array.isArray(input.items) || !input.items.length) throw new SalesWriteError('Cần có sản phẩm trả lại');
    const seen = new Set<number>();
    const items = input.items.map(rawItem => {
        if (!rawItem || typeof rawItem !== 'object' || Array.isArray(rawItem)) throw new SalesWriteError('Dòng sản phẩm trả lại không hợp lệ');
        const item = rawItem as Record<string, unknown>;
        const positiveId = (value: unknown) => (typeof value === 'number' || typeof value === 'string' && /^\d+$/.test(value)) && Number.isSafeInteger(Number(value)) && Number(value) > 0 && Number(value) <= 2147483647;
        if (!positiveId(item.productId) || !positiveId(item.quantity) || seen.has(Number(item.productId))) throw new SalesWriteError('Mã hàng, số lượng hoặc dòng sản phẩm trùng không hợp lệ');
        if (item.reason != null && (typeof item.reason !== 'string' || item.reason.length > 200)) throw new SalesWriteError('Lý do từng sản phẩm không được vượt quá 200 ký tự');
        seen.add(Number(item.productId));
        // Client unitPrice/subtotal are intentionally not authoritative.
        return { productId: Number(item.productId), quantity: Number(item.quantity), reason: item.reason as string | undefined };
    });
    return { items, returnDate, refundAmountCents, refundShippingFee: input.refundShippingFee === true,
        reason: text('reason', 500) ?? '', notes: text('notes', 500), returnCode: text('returnCode', 20) || undefined,
        refundMethod: text('refundMethod', 20), createdBy: input.createdBy };
}
