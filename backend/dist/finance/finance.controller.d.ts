import { FinanceService } from './finance.service';
import { ApiResponse } from '../common/response';
export declare class CashTransactionController {
    private svc;
    constructor(svc: FinanceService);
    findAll(page?: string, limit?: string, type?: string, from?: string, to?: string): Promise<ApiResponse<{
        items: import("./entities").CashTransaction[];
        total: number;
        page: number;
        limit: number;
    }>>;
    create(dto: any): Promise<ApiResponse<import("./entities").CashTransaction>>;
    summary(from: string, to: string): Promise<ApiResponse<{
        totalIncome: any;
        totalExpense: any;
        netCashFlow: number;
    }>>;
    profitLoss(from: string, to: string): Promise<ApiResponse<{
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
    }>>;
}
export declare class DailyClosingController {
    private svc;
    constructor(svc: FinanceService);
    get(date: string): Promise<ApiResponse<import("./entities").DailyClosing | null>>;
    create(dto: any): Promise<ApiResponse<import("./entities").DailyClosing>>;
}
export declare class CashAccountController {
    private svc;
    constructor(svc: FinanceService);
    findAll(): Promise<ApiResponse<import("./entities").CashAccount[]>>;
}
export declare class CashflowForecastController {
    private svc;
    constructor(svc: FinanceService);
    findAll(from?: string, to?: string): Promise<ApiResponse<import("./entities").CashflowForecast[]>>;
    create(dto: any): Promise<ApiResponse<import("./entities").CashflowForecast>>;
    update(id: number, dto: any): Promise<ApiResponse<import("./entities").CashflowForecast>>;
    delete(id: number): Promise<ApiResponse<{
        deleted: boolean;
    }>>;
}
export declare class BudgetPlanController {
    private svc;
    constructor(svc: FinanceService);
    findAll(): Promise<ApiResponse<import("./entities").BudgetPlan[]>>;
    create(dto: any): Promise<ApiResponse<import("./entities").BudgetPlan>>;
    update(id: number, dto: any): Promise<ApiResponse<import("./entities").BudgetPlan>>;
    delete(id: number): Promise<ApiResponse<{
        deleted: boolean;
    }>>;
}
