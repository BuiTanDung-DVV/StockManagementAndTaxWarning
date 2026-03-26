import { Repository } from 'typeorm';
import { Customer, Receivable, DebtEvidence, DebtPaymentHistory } from './entities';
export declare class CustomerService {
    private customerRepo;
    private receivableRepo;
    private evidenceRepo;
    private paymentRepo;
    constructor(customerRepo: Repository<Customer>, receivableRepo: Repository<Receivable>, evidenceRepo: Repository<DebtEvidence>, paymentRepo: Repository<DebtPaymentHistory>);
    findAll(page?: number, limit?: number, search?: string): Promise<{
        items: Customer[];
        total: number;
        page: number;
        limit: number;
        totalPages: number;
    }>;
    findById(id: number): Promise<Customer>;
    create(dto: Partial<Customer>): Promise<Customer>;
    update(id: number, dto: Partial<Customer>): Promise<Customer>;
    findReceivables(customerId: number): Promise<Receivable[]>;
    createReceivable(customerId: number, dto: Partial<Receivable>): Promise<Receivable>;
    addEvidence(receivableId: number, dto: Partial<DebtEvidence>): Promise<DebtEvidence>;
    addPayment(receivableId: number, dto: Partial<DebtPaymentHistory>): Promise<DebtPaymentHistory>;
    findOverdueDebts(): Promise<Receivable[]>;
    getDebtAging(): Promise<{
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
    }>;
}
