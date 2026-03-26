import { SystemService } from './system.service';
import { ApiResponse } from '../common/response';
export declare class ShopProfileController {
    private svc;
    constructor(svc: SystemService);
    get(): Promise<ApiResponse<import("./entities").ShopProfile>>;
    save(dto: any): Promise<ApiResponse<import("./entities").ShopProfile>>;
}
export declare class ActivityLogController {
    private svc;
    constructor(svc: SystemService);
    findAll(page?: string, limit?: string): Promise<ApiResponse<{
        items: import("./entities").ActivityLog[];
        total: number;
        page: number;
        limit: number;
    }>>;
}
export declare class InvoiceScanController {
    private svc;
    constructor(svc: SystemService);
    findAll(page?: string, limit?: string): Promise<ApiResponse<{
        items: import("./entities").InvoiceScan[];
        total: number;
        page: number;
        limit: number;
    }>>;
    create(dto: any): Promise<ApiResponse<import("./entities").InvoiceScan>>;
    update(id: number, dto: any): Promise<ApiResponse<import("./entities").InvoiceScan>>;
}
export declare class InvoiceController {
    private svc;
    constructor(svc: SystemService);
    findAll(page?: string, limit?: string, type?: string, from?: string, to?: string): Promise<ApiResponse<{
        items: import("./entities").Invoice[];
        total: number;
        page: number;
        limit: number;
    }>>;
    summary(from: string, to: string): Promise<ApiResponse<{
        period: {
            from: Date;
            to: Date;
        };
        input: any;
        output: any;
        taxBalance: number;
    }>>;
    findOne(id: number): Promise<ApiResponse<import("./entities").Invoice>>;
    create(dto: any): Promise<ApiResponse<import("./entities").Invoice[]>>;
}
export declare class PurchaseWithoutInvoiceController {
    private svc;
    constructor(svc: SystemService);
    findAll(page?: string, limit?: string): Promise<ApiResponse<{
        items: import("./entities").PurchaseWithoutInvoice[];
        total: number;
        page: number;
        limit: number;
    }>>;
    create(dto: any): Promise<ApiResponse<import("./entities").PurchaseWithoutInvoice[]>>;
}
