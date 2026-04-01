import { CashTransaction, DailyClosing, CashAccount, CashflowForecast, BudgetPlan, Invoice, TaxObligation, PurchaseWithoutInvoice } from '../finance/entities';
export declare class FinanceService {
    private cashTxRepo;
    private closingRepo;
    private accountRepo;
    private forecastRepo;
    private budgetRepo;
    private invoiceRepo;
    private taxObRepo;
    private purchaseNoInvRepo;
    getCashTransactions(page?: number, limit?: number, type?: string, from?: string, to?: string): Promise<{
        items: CashTransaction[];
        total: number;
        page: number;
        limit: number;
        totalPages: number;
    }>;
    createCashTransaction(dto: Partial<CashTransaction>): Promise<CashTransaction>;
    getCashFlowSummary(period?: string): Promise<{
        income: number;
        expense: number;
        balance: number;
        period: string;
    }>;
    getProfitLoss(from?: string, to?: string): Promise<{
        revenue: number;
        cogs: number;
        grossProfit: number;
        expenses: number;
        netProfit: number;
        from: Date;
        to: Date;
    }>;
    getExpensesByCategory(from?: string, to?: string): Promise<{
        categories: {
            category: any;
            amount: number;
            count: number;
        }[];
        total: number;
        recentItems: CashTransaction[];
    }>;
    getDailyClosings(page?: number, limit?: number): Promise<{
        items: DailyClosing[];
        total: number;
        page: number;
        limit: number;
    }>;
    getDailyClosingByDate(date: string): Promise<{
        closingDate: string;
        totalIncome: number;
        totalExpense: number;
        netProfit: number;
        orderCount: number;
        transactions: CashTransaction[];
        closed: boolean;
    } | {
        closed: boolean;
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
        netProfit?: undefined;
        transactions?: undefined;
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
    getInvoices(page?: number, limit?: number, type?: string): Promise<{
        items: Invoice[];
        total: number;
        page: number;
        limit: number;
        totalPages: number;
    }>;
    getInvoiceSummary(from?: string, to?: string): Promise<{
        vatIn: number;
        vatOut: number;
        vatOwed: number;
    }>;
    getInvoiceById(id: number): Promise<Invoice>;
    createInvoice(dto: Partial<Invoice>): Promise<Invoice>;
    getTaxObligations(): Promise<{
        items: TaxObligation[];
        totalVat: number;
        totalPit: number;
        totalPaidVat: number;
        totalPaidPit: number;
        totalOwed: number;
    }>;
    createTaxObligation(dto: Partial<TaxObligation>): Promise<TaxObligation>;
    getPurchasesWithoutInvoice(page?: number, limit?: number): Promise<{
        items: PurchaseWithoutInvoice[];
        total: number;
        totalAmount: number;
        page: number;
        limit: number;
        totalPages: number;
    }>;
    createPurchaseWithoutInvoice(dto: Partial<PurchaseWithoutInvoice>): Promise<PurchaseWithoutInvoice>;
}
