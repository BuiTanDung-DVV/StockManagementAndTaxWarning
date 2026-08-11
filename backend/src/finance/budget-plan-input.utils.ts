import { BudgetPlan } from './entities';

const ALLOWED_PERIODS = new Set(['WEEK', 'MONTH', 'QUARTER', 'YEAR', 'CUSTOM']);

export function normalizeBudgetPlanInput(
    input: Partial<BudgetPlan>,
    current?: BudgetPlan,
) {
    const name = String(input.name ?? current?.name ?? '').trim();
    if (!name || name.length > 200) {
        throw new Error('Validation: Budget name is required and must not exceed 200 characters');
    }

    const period = String(input.period ?? current?.period ?? 'CUSTOM').trim().toUpperCase();
    if (!ALLOWED_PERIODS.has(period)) {
        throw new Error('Validation: Unsupported budget period');
    }

    const startDate = new Date(input.startDate ?? current?.startDate ?? '');
    const endDate = new Date(input.endDate ?? current?.endDate ?? '');
    if (Number.isNaN(startDate.getTime()) || Number.isNaN(endDate.getTime())) {
        throw new Error('Validation: Invalid budget date range');
    }
    if (startDate > endDate) {
        throw new Error('Validation: Budget start date must not be after end date');
    }

    const plannedIncome = Number(input.plannedIncome ?? current?.plannedIncome ?? 0);
    const plannedExpense = Number(input.plannedExpense ?? current?.plannedExpense ?? 0);
    if (!Number.isFinite(plannedIncome) || plannedIncome < 0
        || !Number.isFinite(plannedExpense) || plannedExpense < 0) {
        throw new Error('Validation: Planned amounts must be non-negative');
    }

    const notes = String(input.notes ?? current?.notes ?? '').trim();
    if (notes.length > 500) {
        throw new Error('Validation: Notes must not exceed 500 characters');
    }

    return {
        name,
        period,
        startDate,
        endDate,
        plannedIncome,
        plannedExpense,
        notes: notes || undefined,
    };
}
