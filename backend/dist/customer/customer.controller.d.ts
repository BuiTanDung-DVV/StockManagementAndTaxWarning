import { CustomerService } from './customer.service';
import { ApiResponse } from '../common/response';
export declare class CustomerController {
    private svc;
    constructor(svc: CustomerService);
    findAll(page?: string, limit?: string, search?: string): Promise<ApiResponse<{
        items: import("./entities").Customer[];
        total: number;
        page: number;
        limit: number;
        totalPages: number;
    }>>;
    overdueDebts(): Promise<ApiResponse<import("./entities").Receivable[]>>;
    debtAging(): Promise<ApiResponse<{
        summary: {
            totalOutstanding: number;
            current: number;
            overdue_1_30: number;
            overdue_31_60: number;
            overdue_61_90: number;
            overdue_over_90: number;
        };
        aging: {
            current: any[];
            days_1_30: any[];
            days_31_60: any[];
            days_61_90: any[];
            days_over_90: any[];
        };
    }>>;
    findOne(id: number): Promise<ApiResponse<import("./entities").Customer>>;
    create(dto: any): Promise<ApiResponse<import("./entities").Customer>>;
    update(id: number, dto: any): Promise<ApiResponse<import("./entities").Customer>>;
    receivables(id: number): Promise<ApiResponse<import("./entities").Receivable[]>>;
    createReceivable(id: number, dto: any): Promise<ApiResponse<import("./entities").Receivable>>;
    addEvidence(receivableId: number, dto: any): Promise<ApiResponse<import("./entities").DebtEvidence>>;
    addPayment(receivableId: number, dto: any): Promise<ApiResponse<import("./entities").DebtPaymentHistory>>;
}
