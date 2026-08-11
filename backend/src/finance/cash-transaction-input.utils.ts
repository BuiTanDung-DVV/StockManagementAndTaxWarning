import { CashTransaction } from './entities';

const ALLOWED_TYPES = new Set(['INCOME', 'EXPENSE']);
const BANK_METHODS = new Set([
    'TRANSFER',
    'BANK_TRANSFER',
    'QR',
    'CARD',
    'CREDIT_CARD',
    'MOMO',
    'ZALOPAY',
]);

export function normalizeCashPaymentMethod(value: unknown): string {
    const method = String(value || 'CASH').trim().toUpperCase();
    if (method === 'CASH') return 'CASH';
    if (BANK_METHODS.has(method)) return method;
    throw new Error('Validation: Unsupported payment method');
}
export function cashLedgerAccountCode(paymentMethod: unknown): '111' | '112' {
    return normalizeCashPaymentMethod(paymentMethod) === 'CASH' ? '111' : '112';
}

export function normalizeCashTransactionInput(
    input: Partial<CashTransaction> & { description?: string },
    current?: CashTransaction,
) {
    const type = String(input.type ?? current?.type ?? '').trim().toUpperCase();
    if (!ALLOWED_TYPES.has(type)) {
        throw new Error('Validation: Type must be INCOME or EXPENSE');
    }

    const amount = Number(input.amount ?? current?.amount);
    if (!Number.isFinite(amount) || amount <= 0) {
        throw new Error('Validation: Amount must be greater than 0');
    }

    const category = String(input.category ?? current?.category ?? '').trim().toUpperCase();
    if (!category || category.length > 50) {
        throw new Error('Validation: Category is required and must not exceed 50 characters');
    }

    const rawDate = input.transactionDate ?? current?.transactionDate ?? new Date();
    const transactionDate = new Date(rawDate);
    if (Number.isNaN(transactionDate.getTime())) {
        throw new Error('Validation: Invalid transaction date');
    }

    const notes = String(input.notes ?? input.description ?? current?.notes ?? '').trim();
    if (notes.length > 500) {
        throw new Error('Validation: Notes must not exceed 500 characters');
    }

    const counterparty = String(input.counterparty ?? current?.counterparty ?? '').trim();
    if (counterparty.length > 200) {
        throw new Error('Validation: Counterparty must not exceed 200 characters');
    }

    return {
        type,
        amount,
        category,
        paymentMethod: normalizeCashPaymentMethod(
            input.paymentMethod ?? current?.paymentMethod,
        ),
        transactionDate,
        notes: notes || null,
        counterparty: counterparty || null,
    };
}
