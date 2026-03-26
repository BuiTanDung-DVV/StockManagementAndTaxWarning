import { Repository } from 'typeorm';
import { ShopProfile, ActivityLog, InvoiceScan, Invoice, InvoiceItem, PurchaseWithoutInvoice, PurchaseWithoutInvoiceItem } from './entities';
export declare class SystemService {
    private shopRepo;
    private logRepo;
    private scanRepo;
    private invoiceRepo;
    private invoiceItemRepo;
    private pwiRepo;
    private pwiItemRepo;
    constructor(shopRepo: Repository<ShopProfile>, logRepo: Repository<ActivityLog>, scanRepo: Repository<InvoiceScan>, invoiceRepo: Repository<Invoice>, invoiceItemRepo: Repository<InvoiceItem>, pwiRepo: Repository<PurchaseWithoutInvoice>, pwiItemRepo: Repository<PurchaseWithoutInvoiceItem>);
    getShopProfile(): Promise<ShopProfile>;
    saveShopProfile(dto: Partial<ShopProfile>): Promise<ShopProfile>;
    log(action: string, entityType: string, entityId?: number, entityName?: string, description?: string, userId?: number): Promise<ActivityLog>;
    getLogs(page?: number, limit?: number): Promise<{
        items: ActivityLog[];
        total: number;
        page: number;
        limit: number;
    }>;
    createScan(dto: Partial<InvoiceScan>): Promise<InvoiceScan>;
    updateScan(id: number, dto: Partial<InvoiceScan>): Promise<InvoiceScan>;
    findScans(page?: number, limit?: number): Promise<{
        items: InvoiceScan[];
        total: number;
        page: number;
        limit: number;
    }>;
    findInvoices(page?: number, limit?: number, type?: string, from?: Date, to?: Date): Promise<{
        items: Invoice[];
        total: number;
        page: number;
        limit: number;
    }>;
    findInvoiceById(id: number): Promise<Invoice>;
    createInvoice(dto: any): Promise<Invoice[]>;
    getInvoiceSummary(from: Date, to: Date): Promise<{
        period: {
            from: Date;
            to: Date;
        };
        input: any;
        output: any;
        taxBalance: number;
    }>;
    findPurchasesWithoutInvoice(page?: number, limit?: number): Promise<{
        items: PurchaseWithoutInvoice[];
        total: number;
        page: number;
        limit: number;
    }>;
    createPurchaseWithoutInvoice(dto: any): Promise<PurchaseWithoutInvoice[]>;
}
