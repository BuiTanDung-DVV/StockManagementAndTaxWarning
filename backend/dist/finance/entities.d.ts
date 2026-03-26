export declare class CashAccount {
    id: number;
    name: string;
    accountType: string;
    balance: number;
    isActive: boolean;
}
export declare class CashTransaction {
    id: number;
    transactionCode: string;
    type: string;
    category: string;
    amount: number;
    paymentMethod: string;
    account: CashAccount;
    counterparty: string;
    referenceType: string;
    referenceId: number;
    transactionDate: Date;
    notes: string;
    receiptImageUrl: string;
    runningBalance: number;
    approvedBy: number;
    createdBy: number;
    createdAt: Date;
}
export declare class BudgetPlan {
    id: number;
    name: string;
    period: string;
    startDate: Date;
    endDate: Date;
    plannedIncome: number;
    plannedExpense: number;
    actualIncome: number;
    actualExpense: number;
    notes: string;
    createdAt: Date;
}
export declare class CashflowForecast {
    id: number;
    forecastDate: Date;
    expectedIncome: number;
    expectedExpense: number;
    expectedBalance: number;
    notes: string;
    createdAt: Date;
}
export declare class DailyClosing {
    id: number;
    closingDate: Date;
    openingCash: number;
    closingCash: number;
    expectedCash: number;
    cashDifference: number;
    totalSales: number;
    totalReturns: number;
    totalIncome: number;
    totalExpense: number;
    orderCount: number;
    notes: string;
    closedBy: number;
    closedAt: Date;
}
