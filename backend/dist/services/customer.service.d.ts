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
}
