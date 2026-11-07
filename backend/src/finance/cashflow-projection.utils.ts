type DatedAmount = { date: string; amount: number | string };
type Plan = { date: string; income: number | string; expense: number | string };
const money = (value: number) => Math.round(value * 100) / 100;
export function buildCashflowProjection(input: {
    asOf: string; days: number; bookBalance: number; receivables: DatedAmount[]; payables: DatedAmount[]; plans: Plan[];
}) {
    const daily = Array.from({ length: input.days }, (_, index) => {
        const date = new Date(`${input.asOf}T00:00:00Z`);
        date.setUTCDate(date.getUTCDate() + index + 1);
        return { date: date.toISOString().slice(0, 10), receivableIncome: 0, payableExpense: 0, plannedIncome: 0, plannedExpense: 0, income: 0, expense: 0, balance: 0 };
    });
    const byDate = new Map(daily.map(row => [row.date, row]));
    let dueIncome = 0, dueExpense = 0;
    for (const item of input.receivables) {
        if (item.date <= input.asOf) dueIncome += Number(item.amount);
        else { const row = byDate.get(item.date); if (row) row.receivableIncome += Number(item.amount); }
    }
    for (const item of input.payables) {
        if (item.date <= input.asOf) dueExpense += Number(item.amount);
        else { const row = byDate.get(item.date); if (row) row.payableExpense += Number(item.amount); }
    }
    for (const plan of input.plans) {
        const row = byDate.get(plan.date);
        if (row) { row.plannedIncome += Number(plan.income); row.plannedExpense += Number(plan.expense); }
    }
    let balance = money(input.bookBalance), expectedIncome = 0, expectedExpense = 0;
    for (const row of daily) {
        row.income = money(row.receivableIncome + row.plannedIncome);
        row.expense = money(row.payableExpense + row.plannedExpense);
        expectedIncome = money(expectedIncome + row.income);
        expectedExpense = money(expectedExpense + row.expense);
        balance = money(balance + row.income - row.expense);
        row.balance = balance;
    }
    return {
        asOf: input.asOf, days: input.days, throughDate: daily[daily.length - 1].date,
        bookBalance: money(input.bookBalance), expectedIncome, expectedExpense, closingBalance: balance,
        minimumBalance: Math.min(input.bookBalance, ...daily.map(row => row.balance)),
        firstShortfallDate: daily.find(row => row.balance < 0)?.date || null,
        dueIncome: money(dueIncome), dueExpense: money(dueExpense), daily,
    };
}
