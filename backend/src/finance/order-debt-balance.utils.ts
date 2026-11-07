import { OpeningBalanceEffects, openingAdjustedDebt, openingEffectCents, openingEffectValue } from './opening-balance-effects.repository';

export interface DebtOrder {
    id: number; shopId: number; totalAmount: unknown; paidAmount: unknown; status: string;
    supplierId?: number; customer?: { id: number; shopId: number }; returnStatus?: string;
    shippingFee?: unknown; shippingFeePayer?: string; shippingTaxRate?: unknown;
    returnedProof?: { count: number; refundedAmount: string; refundShippingFee: boolean; returnDate: string; reversedAmount?: string };
}
export interface OrderDebtRow {
    id: number; order_id: number; shop_id: number; party_id: number;
    amount: string; paid_amount: string; status: string;
}

/** A current debt read model; actual total/paid values are never rewritten. */
export function orderDebtBalance(kind: 'PURCHASE' | 'SALES', order: DebtOrder, rows: OrderDebtRow[], effects: OpeningBalanceEffects, asOf: string) {
    const total = openingEffectCents(order.totalAmount), paid = openingEffectCents(order.paidAmount ?? 0);
    if (total < 0n || paid < 0n) throw new Error('Giá trị đơn hàng không hợp lệ');
    const base = { balanceAsOf: asOf, openingAdjustmentAmount: 0, closedByAdjustment: false, openingEffective: true };
    if (order.status === 'CANCELLED') {
        return { ...base, remainingAmount: 0, debtBalanceBasis: 'CLOSED' as const };
    }
    if (kind === 'SALES' && ['PARTIAL_RETURN', 'FULL_RETURN', 'RETURNED'].includes(order.returnStatus ?? '')) {
        const partial = order.returnStatus === 'PARTIAL_RETURN';
        const active = rows.filter(row => row.status !== 'CANCELLED');
        const fail = (issue: string) => ({ ...base, remainingAmount: null, debtBalanceBasis: 'RECONCILIATION_REQUIRED' as const, debtBalanceIssue: issue });
        const proof = order.returnedProof;
        if (!proof) return !partial && !active.length ? { ...base, remainingAmount: 0, debtBalanceBasis: 'CLOSED' as const } : fail('RETURN_SOURCE_MISSING');
        if (proof.count < 1 || (proof.count > 1 || partial) && proof.reversedAmount === undefined || proof.returnDate > asOf) return fail('RETURN_SOURCE_MISMATCH');
        const refunded = openingEffectCents(proof.refundedAmount);
        if (refunded < 0n || refunded > paid) return fail('RETURN_PAYMENT_MISMATCH');
        const shipping = order.shippingFeePayer === 'CUSTOMER' && !proof.refundShippingFee
            ? openingEffectCents((Number(order.shippingFee || 0) * (1 + Number(order.shippingTaxRate || 0) / 100)).toFixed(2)) : 0n;
        const adjustment = rows.length === 1 ? effects.receivableCents.get(Number(rows[0].id)) ?? 0n : 0n;
        const reversed = proof.reversedAmount === undefined ? undefined : openingEffectCents(proof.reversedAmount);
        if (reversed !== undefined && (reversed < 0n || reversed > total)) return fail('RETURN_VALUE_MISMATCH');
        const expectedRaw = partial
            ? total - reversed! - (paid - refunded) + adjustment
            : shipping - (paid - refunded) + adjustment;
        const expected = expectedRaw > 0n ? expectedRaw : 0n;
        if (rows.length > 0 && (rows.some(row => Number(row.shop_id) !== order.shopId || Number(row.order_id) !== order.id || Number(row.party_id) !== order.customer?.id)
            || order.customer?.shopId !== order.shopId)) return fail('PARTY_MISMATCH');
        const info = { ...base, refundedAmount: openingEffectValue(refunded), retainedShippingAmount: openingEffectValue(shipping), lastReturnDate: proof.returnDate };
        if (!active.length) return expected === 0n ? { ...info, remainingAmount: 0, debtBalanceBasis: 'CLOSED' as const } : fail('RETURN_LINKED_DEBT_MISSING');
        if (active.length !== 1) return fail('LINKED_DEBT_COUNT');
        const row = active[0];
        if ((effects.receivableDates.get(Number(row.id)) ?? '') > asOf) return fail('RETURN_OPENING_SOURCE_FUTURE');
        if (adjustment > 0n) return fail('RETURN_ADJUSTMENT_INVALID');
        const balance = openingAdjustedDebt(row.amount, row.paid_amount, adjustment);
        if (balance.remainingCents !== expected) return fail('RETURN_AMOUNT_MISMATCH');
        return { ...info, openingAdjustmentAmount: openingEffectValue(adjustment), closedByAdjustment: balance.closedByAdjustment, remainingAmount: openingEffectValue(balance.remainingCents), debtBalanceBasis: partial ? 'PARTIAL_RETURN_LEDGER' as const : 'RETURN_LEDGER' as const };
    }
    if (kind === 'PURCHASE' && order.status !== 'COMPLETED') {
        return { ...base, remainingAmount: 0, openingEffective: false, debtBalanceBasis: 'NOT_POSTED' as const };
    }
    const raw = total - paid;
    if (!rows.length) return { ...base, remainingAmount: openingEffectValue(raw > 0n ? raw : 0n), debtBalanceBasis: 'ORDER' as const };
    const partyId = kind === 'PURCHASE' ? order.supplierId : order.customer?.id;
    const scopeIssue = (kind === 'SALES' && order.customer?.shopId !== order.shopId)
        || rows.some(row => Number(row.shop_id) !== order.shopId || Number(row.order_id) !== order.id || Number(row.party_id) !== partyId);
    const active = rows.filter(row => row.status !== 'CANCELLED');
    let issue = scopeIssue ? 'PARTY_MISMATCH' : active.length !== 1 ? 'LINKED_DEBT_COUNT' : '';
    if (!issue && openingEffectCents(active[0].amount) - openingEffectCents(active[0].paid_amount) !== raw) issue = 'AMOUNT_MISMATCH';
    if (issue) return { ...base, remainingAmount: null, debtBalanceBasis: 'RECONCILIATION_REQUIRED' as const, debtBalanceIssue: issue };
    const row = active[0];
    const offsets = kind === 'PURCHASE' ? effects.payableCents : effects.receivableCents;
    const dates = kind === 'PURCHASE' ? effects.payableDates : effects.receivableDates;
    if ((dates.get(Number(row.id)) ?? '') > asOf) return {
        ...base, remainingAmount: 0, openingEffective: false, debtBalanceBasis: 'LEDGER' as const,
    };
    const adjustment = offsets.get(Number(row.id)) ?? 0n;
    const balance = openingAdjustedDebt(row.amount, row.paid_amount, adjustment);
    return {
        ...base, remainingAmount: openingEffectValue(balance.remainingCents),
        openingAdjustmentAmount: openingEffectValue(adjustment), closedByAdjustment: balance.closedByAdjustment,
        debtBalanceBasis: 'LEDGER' as const,
    };
}
