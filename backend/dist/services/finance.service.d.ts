import { CashTransaction, DailyClosing, CashAccount, CashflowForecast, BudgetPlan } from '../finance/entities';
export declare class FinanceService {
    private cashTxRepo;
    private closingRepo;
    private accountRepo;
    private forecastRepo;
    private budgetRepo;
    getCashTransactions(page?: number, limit?: number): Promise<{
        items: CashTransaction[];
        total: number;
        page: number;
        limit: number;
        totalPages: number;
    }>;
    createCashTransaction(dto: Partial<CashTransaction>): Promise<CashTransaction>;
    getCashFlowSummary(period: string): Promise<{
        income: number;
        expense: number;
        balance: number;
        period: string;
    }>;
    getProfitLoss(from: string, to: string): Promise<{
        revenue: number;
        cogs: number;
        grossProfit: number;
        expenses: number;
        netProfit: number;
    }>;
    getDailyClosings(page?: number, limit?: number): Promise<{
        items: DailyClosing[];
        total: number;
        page: number;
        limit: number;
    }>;
    createDailyClosing(dto: Partial<DailyClosing>): Promise<DailyClosing>;
    getCashAccounts(): Promise<CashAccount[]>;
    getForecasts(): Promise<CashflowForecast[]>;
    createForecast(dto: Partial<CashflowForecast>): Promise<CashflowForecast>;
    updateForecast(id: number, dto: Partial<CashflowForecast>): Promise<CashflowForecast>;
    deleteForecast(id: number): Promise<void>;
    getBudgetPlans(): Promise<BudgetPlan[]>;
    createBudgetPlan(dto: Partial<BudgetPlan>): Promise<BudgetPlan>;
    updateBudgetPlan(id: number, dto: Partial<BudgetPlan>): Promise<BudgetPlan>;
    deleteBudgetPlan(id: number): Promise<void>;
}
