import { SalesOrder, SalesReturn, SalesOrderPayment } from '../sales/entities';
export declare class SalesService {
    private orderRepo;
    private orderItemRepo;
    private returnRepo;
    private paymentRepo;
    private customerRepo;
    private productRepo;
    private cogsService;
    findAll(page?: number, limit?: number): Promise<{
        items: SalesOrder[];
        total: number;
        page: number;
        limit: number;
        totalPages: number;
    }>;
    summary(from?: string, to?: string): Promise<{
        totalRevenue: number;
        totalCogs: number;
        grossProfit: number;
        orderCount: number;
    }>;
    findById(id: number): Promise<any>;
    create(dto: any): Promise<SalesOrder[]>;
    cancel(id: number): Promise<any>;
    addPayment(orderId: number, dto: Partial<SalesOrderPayment>): Promise<SalesOrderPayment>;
    createReturn(orderId: number, dto: any): Promise<SalesReturn[]>;
}
