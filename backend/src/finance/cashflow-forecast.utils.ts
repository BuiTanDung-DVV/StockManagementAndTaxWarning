export type CashflowForecastInput = {
    forecastDate?: Date | string;
    expectedIncome?: number | string;
    expectedExpense?: number | string;
    notes?: string | null;
};

export function normalizeCashflowForecastInput(
    input: CashflowForecastInput,
    existing: CashflowForecastInput = {},
) {
    const rawDate = input.forecastDate ?? existing.forecastDate;
    const forecastDate = rawDate instanceof Date ? rawDate : new Date(String(rawDate || ''));
    if (Number.isNaN(forecastDate.getTime())) {
        throw new Error('Validation: Ngày dự báo không hợp lệ');
    }

    const expectedIncome = Number(
        input.expectedIncome ?? existing.expectedIncome ?? 0,
    );
    const expectedExpense = Number(
        input.expectedExpense ?? existing.expectedExpense ?? 0,
    );
    if (!Number.isFinite(expectedIncome) || expectedIncome < 0) {
        throw new Error('Validation: Thu dự kiến phải là số không âm');
    }
    if (!Number.isFinite(expectedExpense) || expectedExpense < 0) {
        throw new Error('Validation: Chi dự kiến phải là số không âm');
    }

    const rawNotes = input.notes === undefined ? existing.notes : input.notes;
    const notes = String(rawNotes || '').trim() || undefined;
    if (String(notes || '').length > 500) {
        throw new Error('Validation: Ghi chú dự báo tối đa 500 ký tự');
    }

    return {
        forecastDate,
        expectedIncome,
        expectedExpense,
        // Authoritative server calculation; never trust a client-provided balance.
        expectedBalance: expectedIncome - expectedExpense,
        notes,
    };
}
