import { openingEffectCents as cents, openingEffectValue as value } from '../finance/opening-balance-effects.repository';
import { normalizeSettledPaymentMethod } from './payment-ledger.utils';

type SoldLine = { productId?: number; product?: { id: number }; quantity: unknown; subtotal: unknown; unitPrice: unknown; taxAmount?: unknown };
type Returned = { id?: number; refundAmount: unknown; refundShippingFee?: boolean; status: string; items?: Array<{ product?: { id: number }; productId?: number; quantity: unknown }> };
type Order = { subtotal: unknown; discountAmount: unknown; taxAmount: unknown; totalAmount: unknown; paidAmount: unknown;
    shippingFee?: unknown; shippingTaxRate?: unknown; shippingFeePayer?: string; items: SoldLine[] };
const fail = (message: string): never => { throw new Error(`Validation: ${message}`); };
const roundedRatio = (amount: bigint, n: number, d: number) => (amount * BigInt(n) * 2n + BigInt(d)) / (BigInt(d) * 2n);

/** Allocate cents once to stable product IDs, so repeated partial returns cannot lose a cent. */
function allocate(amount: bigint, weights: bigint[]): bigint[] {
    const total = weights.reduce((a, b) => a + b, 0n);
    if (amount < 0n || weights.some(w => w < 0n) || total === 0n && amount !== 0n) return fail('Giá trị phân bổ cần đối chiếu');
    if (total === 0n) return weights.map(() => 0n);
    const shares = weights.map(w => amount * w / total);
    const remainder = weights.map((w, index) => ({ index, remainder: amount * w % total }))
        .sort((a, b) => a.remainder === b.remainder ? a.index - b.index : a.remainder > b.remainder ? -1 : 1);
    let left = amount - shares.reduce((a, b) => a + b, 0n);
    for (const row of remainder) { if (left-- <= 0n) break; shares[row.index]++; }
    return shares;
}

export function planPartialReturn(order: Order, previous: Returned[], requested: Array<{ productId: number; quantity: number }>, refundShipping: boolean) {
    const lines = [...order.items].sort((a, b) => Number(a.productId ?? a.product?.id) - Number(b.productId ?? b.product?.id));
    const ids = lines.map(l => Number(l.productId ?? l.product?.id));
    const qty = lines.map(l => Number(l.quantity));
    if (new Set(ids).size !== ids.length || ids.some(id => !Number.isSafeInteger(id) || id <= 0) || qty.some(q => !Number.isSafeInteger(q) || q <= 0)) return fail('Các dòng hàng của đơn cần đối chiếu');
    const gross = lines.map(l => cents(l.subtotal));
    const subtotal = cents(order.subtotal), discount = cents(order.discountAmount ?? 0), tax = cents(order.taxAmount ?? 0);
    if (subtotal < 0n || gross.some(g => g < 0n) || gross.reduce((a, b) => a + b, 0n) !== subtotal || discount < 0n || discount > subtotal || tax < 0n) return fail('Tiền hàng, giảm giá hoặc thuế cần đối chiếu');
    const discounts = allocate(discount, gross);
    const net = gross.map((g, i) => g - discounts[i]);
    const taxWeights = lines.map(l => cents(l.taxAmount ?? 0));
    if (taxWeights.some(t => t < 0n)) return fail('Thuế từng dòng hàng cần đối chiếu');
    const taxes = allocate(tax, taxWeights.some(t => t > 0n) ? taxWeights : gross);
    const priorQty = new Map<number, number>();
    let previousRefund = 0n;
    let feeAlreadyRefunded = false;
    for (const row of previous.filter(r => r.status === 'COMPLETED')) {
        const refund = cents(row.refundAmount);
        if (refund < 0n) return fail('Lịch sử hoàn tiền cần đối chiếu');
        previousRefund += refund;
        if (feeAlreadyRefunded && row.refundShippingFee) return fail('Lịch sử hoàn phí giao hàng bị trùng');
        feeAlreadyRefunded ||= row.refundShippingFee === true;
        for (const item of row.items ?? []) {
            const id = Number(item.productId ?? item.product?.id), q = Number(item.quantity);
            if (!ids.includes(id) || !Number.isSafeInteger(q) || q <= 0) return fail('Lịch sử số lượng trả cần đối chiếu');
            priorQty.set(id, (priorQty.get(id) ?? 0) + q);
        }
    }
    const selected = new Map<number, number>();
    for (const item of requested) {
        if (selected.has(item.productId) || !ids.includes(item.productId) || !Number.isSafeInteger(item.quantity) || item.quantity <= 0) return fail('Mặt hàng hoặc số lượng trả không hợp lệ');
        selected.set(item.productId, item.quantity);
    }
    if (!selected.size) return fail('Chọn ít nhất một mặt hàng để trả');
    let returnNet = 0n, returnTax = 0n, grossReturn = 0n;
    let previousMerchandise = 0n;
    let allReturned = true;
    const items = lines.map((line, i) => {
        const before = priorQty.get(ids[i]) ?? 0, take = selected.get(ids[i]) ?? 0, after = before + take;
        if (before > qty[i] || after > qty[i]) return fail('Số lượng trả vượt phần hàng còn được trả');
        allReturned &&= after === qty[i];
        const netBefore = roundedRatio(net[i], before, qty[i]), taxBefore = roundedRatio(taxes[i], before, qty[i]);
        previousMerchandise += netBefore + taxBefore;
        returnNet += roundedRatio(net[i], after, qty[i]) - netBefore;
        returnTax += roundedRatio(taxes[i], after, qty[i]) - taxBefore;
        const itemGross = roundedRatio(gross[i], after, qty[i]) - roundedRatio(gross[i], before, qty[i]);
        grossReturn += itemGross;
        return { productId: ids[i], quantity: take, unitPrice: Number(line.unitPrice), subtotal: value(itemGross) };
    }).filter(l => l.quantity > 0);
    const shippingBase = order.shippingFeePayer === 'CUSTOMER' ? cents(order.shippingFee ?? 0) : 0n;
    const shippingTax = shippingBase > 0n ? cents((Number(order.shippingFee) * Number(order.shippingTaxRate ?? 0) / 100).toFixed(2)) : 0n;
    const fee = shippingBase + shippingTax;
    if (shippingBase < 0n || shippingTax < 0n || cents(order.totalAmount) !== subtotal - discount + tax + fee) return fail('Tổng thanh toán của đơn cần đối chiếu');
    if (refundShipping && feeAlreadyRefunded) return fail('Phí giao hàng đã được hoàn trong phiếu trước');
    const paid = cents(order.paidAmount ?? 0), availableCash = paid - previousRefund;
    if (availableCash < 0n || paid > cents(order.totalAmount)) return fail('Tiền đã thu và đã hoàn cần đối chiếu');
    const reverseShipping = refundShipping && fee > 0n;
    const reversal = returnNet + returnTax + (reverseShipping ? fee : 0n);
    const refund = availableCash < reversal ? availableCash : reversal;
    return {
        items, allReturned, returnNet, returnTax, grossReturn, previousMerchandise, previousRefund,
        reversal, refund, shippingBase, shippingTax, fee, feeAlreadyRefunded,
        refundShippingFee: reverseShipping,
        refundedShippingAmount: reverseShipping && refund > returnNet + returnTax ? refund - returnNet - returnTax : 0n,
    };
}

export function partialReturnDebtPlan(input: { amount: unknown; paidAmount: unknown; adjustment: bigint; reversal: bigint; refund: bigint }) {
    const amount = cents(input.amount), paid = cents(input.paidAmount), before = amount - paid + input.adjustment;
    if (amount < paid || input.adjustment > 0n || before < 0n || input.refund < 0n || input.refund > input.reversal) return fail('Công nợ trước trả hàng cần đối chiếu');
    const reduction = input.reversal - input.refund;
    const debtReduction = reduction > before ? before : reduction;
    const clearing = reduction - debtReduction;
    if (clearing > -input.adjustment) return fail('Khoản hoàn và giảm nợ chưa khớp');
    return { remaining: before - debtReduction, amount: amount - debtReduction, paid, debtReduction, clearing };
}

export function allocateReturnRefund(receipts: Array<{ amount: unknown; method: string }>, priorCash: Array<{ amount: unknown; method: string }>, previousRefund: bigint, refund: bigint) {
    const method = (raw: string) => {
        const result = normalizeSettledPaymentMethod(raw);
        return result === 'BANK_TRANSFER' ? 'TRANSFER' : result === 'CREDIT_CARD' ? 'CARD' : result;
    };
    const available = new Map<string, bigint>();
    for (const receipt of receipts) {
        const key = method(receipt.method);
        available.set(key, (available.get(key) ?? 0n) + cents(receipt.amount));
    }
    let refunded = 0n;
    for (const row of priorCash) {
        const key = method(row.method), amount = cents(row.amount);
        if (amount <= 0n || amount > (available.get(key) ?? 0n)) return fail('Lịch sử hoàn tiền theo phương thức cần đối chiếu');
        available.set(key, available.get(key)! - amount); refunded += amount;
    }
    if (refunded !== previousRefund) return fail('Phiếu chi hoàn tiền trước đó chưa khớp phiếu trả hàng');
    let remaining = refund;
    const result: Array<{ method: string; amount: number }> = [];
    for (const [key, amount] of available) {
        const take = amount < remaining ? amount : remaining;
        if (take > 0n) result.push({ method: key, amount: value(take) });
        remaining -= take;
    }
    if (remaining !== 0n) return fail('Số tiền hoàn vượt số thực thu còn lại');
    return result;
}
