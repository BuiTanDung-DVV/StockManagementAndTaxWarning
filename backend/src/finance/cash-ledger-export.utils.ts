import { CashTransactionQueryInput, normalizeCashTransactionQuery } from './finance-period.utils';

export class CashLedgerExportInputError extends Error {}

const validDateKey = (value: unknown): value is string => {
    if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
    const date = new Date(`${value}T00:00:00Z`);
    return Number.isFinite(date.getTime()) && date.toISOString().slice(0, 10) === value;
};

export const normalizeCashLedgerExportQuery = (input: CashTransactionQueryInput) => {
    if (!validDateKey(input.from) || !validDateKey(input.to) || input.from > input.to) {
        throw new CashLedgerExportInputError('Khoảng ngày xuất không hợp lệ.');
    }
    if (input.type !== undefined &&
        (typeof input.type !== 'string' || !['INCOME', 'EXPENSE'].includes(input.type.trim()))) {
        throw new CashLedgerExportInputError('Loại giao dịch không hợp lệ.');
    }
    if (input.category !== undefined &&
        (typeof input.category !== 'string' || !input.category.trim() || input.category.length > 50)) {
        throw new CashLedgerExportInputError('Nhóm giao dịch không hợp lệ.');
    }
    return normalizeCashTransactionQuery(input);
};

const amountCents = (value: unknown) => {
    const text = String(value);
    if (!/^\d+(?:\.\d{1,2})?$/.test(text)) throw new Error('Invalid ledger amount');
    const [whole, decimal = ''] = text.split('.');
    const cents = Number(whole) * 100 + Number(decimal.padEnd(2, '0'));
    if (!Number.isSafeInteger(cents)) throw new Error('Unsafe ledger amount');
    return cents;
};

// All totals derive from the same SELECT result; no paged assembly or separate
// sum query that could observe a different state while another user is writing.
export const summarizeCashLedgerExport = (items: Array<{ type: string; amount: unknown }>) => {
    let income = 0; let expense = 0;
    for (const item of items) {
        const cents = amountCents(item.amount);
        if (item.type === 'INCOME') income += cents;
        else if (item.type === 'EXPENSE') expense += cents;
        else throw new Error('Invalid ledger type');
        if (!Number.isSafeInteger(income) || !Number.isSafeInteger(expense)) {
            throw new Error('Unsafe ledger total');
        }
    }
    return { recordCount: items.length, income: income / 100,
        expense: expense / 100, netCashFlow: (income - expense) / 100 };
};
