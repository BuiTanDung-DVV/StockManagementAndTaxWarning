import { openingAdjustedDebt, openingEffectCents } from '../finance/opening-balance-effects.repository';

/** Keep a prior debt reduction for the customer, without treating it as cash. */
export function salesReturnDebtPlan(input: { amount: unknown; paidAmount: unknown; adjustment: bigint; retainedShipping: unknown; reversal: unknown; refund: unknown }) {
    const debt = openingAdjustedDebt(input.amount, input.paidAmount, input.adjustment);
    if (input.adjustment > 0n || debt.amountCents < debt.paidCents || debt.amountCents - debt.paidCents + input.adjustment < 0n) {
        throw new Error('Validation: Công nợ và điều chỉnh trước trả hàng cần đối chiếu');
    }
    const fee = openingEffectCents(input.retainedShipping);
    const rawShipping = fee < debt.amountCents - debt.paidCents ? fee : debt.amountCents - debt.paidCents;
    if (fee < 0n) throw new Error('Validation: Phí giao hàng không hợp lệ');
    const adjustedShipping = rawShipping + input.adjustment;
    const remaining = adjustedShipping > 0n ? adjustedShipping : 0n;
    const debtReduction = debt.remainingCents - remaining;
    const clearing = openingEffectCents(input.reversal) - openingEffectCents(input.refund) - debtReduction;
    if (debtReduction < 0n || clearing < 0n || clearing > -input.adjustment) throw new Error('Validation: Số tiền hoàn và công nợ chưa khớp');
    return { remaining, amount: debt.paidCents + remaining - input.adjustment, paid: debt.paidCents, debtReduction, clearing };
}
