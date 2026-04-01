import { Customer, Receivable, DebtEvidence, DebtPaymentHistory } from '../customer/entities';
export declare class CustomerService {
    private customerRepo;
    private receivableRepo;
    private evidenceRepo;
    private paymentRepo;
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
    remove(id: number): Promise<Customer>;
    getReceivables(customerId: number): Promise<Receivable[]>;
    getDebtEvidence(customerId: number): Promise<DebtEvidence[]>;
    addPayment(customerId: number, receivableId: number, dto: Partial<DebtPaymentHistory>): Promise<DebtPaymentHistory>;
    getDebtAging(): Promise<{
        buckets: {
            current: number;
            days30: number;
            days60: number;
            days90: number;
            over90: number;
        };
        totalDebt: number;
        receivableCount: number;
    }>;
    getOverdueDebts(): Promise<{
        customerId: number;
        customerName: string;
        phone: string;
        amount: number;
        paidAmount: number;
        remaining: number;
        dueDate: Date;
        daysOverdue: number;
    }[]>;
}
