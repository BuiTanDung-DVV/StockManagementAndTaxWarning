export interface DebtPaymentResult {
    paidAmount: number;
    remaining: number;
    status: 'PARTIAL' | 'PAID';
}

const asNonNegative = (value: number): number => {
    if (!Number.isFinite(value)) return 0;
    return Math.max(0, value);
};

export const calculateRemainingDebt = (
    amount: number,
    paidAmount: number,
): number => {
    return Math.max(asNonNegative(amount) - asNonNegative(paidAmount), 0);
};

export const applyDebtPayment = (
    amount: number,
    paidAmount: number,
    paymentAmount: number,
): DebtPaymentResult => {
    const safePayment = asNonNegative(paymentAmount);
    if (safePayment <= 0) {
        throw new Error('Validation: Payment amount must be greater than 0');
    }

    const currentPaid = asNonNegative(paidAmount);
    const remainingBeforePayment = calculateRemainingDebt(amount, currentPaid);
    if (safePayment > remainingBeforePayment) {
        throw new Error(
            'Validation: Payment amount exceeds remaining receivable balance',
        );
    }

    const nextPaid = currentPaid + safePayment;
    const remaining = calculateRemainingDebt(amount, nextPaid);
    return {
        paidAmount: nextPaid,
        remaining,
        status: remaining === 0 ? 'PAID' : 'PARTIAL',
    };
};
