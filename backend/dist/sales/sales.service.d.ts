import { Repository } from 'typeorm';
import { SalesOrder, SalesOrderItem, SalesOrderPayment, SalesReturn, SalesReturnItem } from './entities';
export declare class SalesService {
    private orderRepo;
    private itemRepo;
    private paymentRepo;
    private returnRepo;
    private returnItemRepo;
    constructor(orderRepo: Repository<SalesOrder>, itemRepo: Repository<SalesOrderItem>, paymentRepo: Repository<SalesOrderPayment>, returnRepo: Repository<SalesReturn>, returnItemRepo: Repository<SalesReturnItem>);
    findAll(page?: number, limit?: number, status?: string): Promise<{
        items: SalesOrder[];
        total: number;
        page: number;
        limit: number;
        totalPages: number;
    }>;
    findById(id: number): Promise<SalesOrder>;
    createOrder(dto: {
        customerId?: number;
        items: {
            productId: number;
            quantity: number;
            unitPrice: number;
        }[];
        paymentMethod?: string;
        notes?: string;
    }): Promise<SalesOrder>;
    cancelOrder(id: number): Promise<SalesOrder>;
    addPayment(orderId: number, dto: {
        amount: number;
        method: string;
        referenceCode?: string;
        notes?: string;
    }): Promise<SalesOrderPayment>;
    createReturn(orderId: number, dto: {
        reason: string;
        items: {
            productId: number;
            quantity: number;
            unitPrice: number;
            reason?: string;
        }[];
    }): Promise<SalesReturn>;
    getSalesSummary(from: Date, to: Date): Promise<any>;
}
