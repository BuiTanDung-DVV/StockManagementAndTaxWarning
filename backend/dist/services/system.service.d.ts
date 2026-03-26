import { ShopProfile, ActivityLog, InvoiceScan, Invoice, PurchaseWithoutInvoice } from '../system/entities';
export declare class SystemService {
    private profileRepo;
    private logRepo;
    private scanRepo;
    private invoiceRepo;
    private pwioRepo;
    getShopProfile(id?: number): Promise<ShopProfile>;
    updateShopProfile(id: number | undefined, dto: Partial<ShopProfile>): Promise<ShopProfile>;
    getActivityLogs(page?: number, limit?: number): Promise<{
        items: ActivityLog[];
        total: number;
        page: number;
        limit: number;
        totalPages: number;
    }>;
    getInvoices(page?: number, limit?: number): Promise<{
        items: Invoice[];
        total: number;
        page: number;
        limit: number;
        totalPages: number;
    }>;
    scanInvoice(dto: any): Promise<InvoiceScan[]>;
    getPurchaseWithoutInvoice(page?: number, limit?: number): Promise<{
        items: PurchaseWithoutInvoice[];
        total: number;
        page: number;
        limit: number;
        totalPages: number;
    }>;
}
