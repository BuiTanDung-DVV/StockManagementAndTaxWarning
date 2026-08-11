const bankLikeMethods = new Set([
    'TRANSFER',
    'BANK_TRANSFER',
    'QR',
    'CARD',
    'CREDIT_CARD',
    'MOMO',
    'ZALOPAY',
]);

export function normalizeSettledPaymentMethod(method?: string | null) {
    const normalized = String(method || 'CASH').trim().toUpperCase();
    if (normalized === 'CASH' || bankLikeMethods.has(normalized)) {
        return normalized;
    }
    throw new Error('Validation: Unsupported settled payment method');
}

export function paymentLedgerAccountCode(method?: string | null): '111' | '112' {
    return normalizeSettledPaymentMethod(method) === 'CASH' ? '111' : '112';
}

export function groupSettledPaymentsByMethod(
    payments: Array<{ method?: string | null; amount?: number | string | null }>,
) {
    const grouped = new Map<string, number>();
    for (const payment of payments) {
        const method = normalizeSettledPaymentMethod(payment.method);
        const amount = Number(payment.amount || 0);
        if (!Number.isFinite(amount) || amount <= 0) {
            throw new Error('Validation: Invalid settled payment amount');
        }
        grouped.set(method, (grouped.get(method) || 0) + amount);
    }
    return Array.from(grouped, ([method, amount]) => ({ method, amount }));
}
