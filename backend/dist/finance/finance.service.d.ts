import { Repository } from 'typeorm';
import { CashTransaction, CashAccount, DailyClosing, BudgetPlan, CashflowForecast } from './entities';
export declare class FinanceService {
    private txRepo;
    private accountRepo;
    private closingRepo;
    private budgetRepo;
    private forecastRepo;
    constructor(txRepo: Repository<CashTransaction>, accountRepo: Repository<CashAccount>, closingRepo: Repository<DailyClosing>, budgetRepo: Repository<BudgetPlan>, forecastRepo: Repository<CashflowForecast>);
    findTransactions(page?: number, limit?: number, type?: string, from?: Date, to?: Date): Promise<{
        items: CashTransaction[];
        total: number;
        page: number;
        limit: number;
    }>;
    createTransaction(dto: Partial<CashTransaction>): Promise<CashTransaction>;
    getCashFlowSummary(from: Date, to: Date): Promise<{
        totalIncome: any;
        totalExpense: any;
        netCashFlow: number;
    }>;
    createDailyClosing(dto: Partial<DailyClosing>): Promise<DailyClosing>;
    getDailyClosing(date: string): Promise<DailyClosing | null>;
    findAccounts(): Promise<CashAccount[]>;
    findForecasts(from?: Date, to?: Date): Promise<CashflowForecast[]>;
    createForecast(dto: Partial<CashflowForecast>): Promise<CashflowForecast>;
    updateForecast(id: number, dto: Partial<CashflowForecast>): Promise<CashflowForecast>;
    deleteForecast(id: number): Promise<{
        deleted: boolean;
    }>;
    findBudgetPlans(): Promise<BudgetPlan[]>;
    createBudgetPlan(dto: Partial<BudgetPlan>): Promise<BudgetPlan>;
    updateBudgetPlan(id: number, dto: Partial<BudgetPlan>): Promise<BudgetPlan>;
    deleteBudgetPlan(id: number): Promise<{
        deleted: boolean;
    }>;
    getProfitLossReport(from: Date, to: Date): Promise<{
        period: {
            from: Date;
            to: Date;
        };
        totalRevenue: number;
        totalCOGS: number;
        grossProfit: number;
        operatingExpenses: any[];
        totalOperatingExpenses: any;
        netProfit: number;
        profitMargin: string;
    }>;
}
