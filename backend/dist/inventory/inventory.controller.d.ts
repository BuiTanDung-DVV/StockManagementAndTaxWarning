import { InventoryService } from './inventory.service';
import { ApiResponse } from '../common/response';
export declare class InventoryController {
    private svc;
    constructor(svc: InventoryService);
    stock(wid?: string): Promise<ApiResponse<import("./entities").InventoryStock[]>>;
    lowStock(t?: string): Promise<ApiResponse<import("./entities").InventoryStock[]>>;
    movements(pid?: string, page?: string, limit?: string): Promise<ApiResponse<{
        items: import("./entities").InventoryMovement[];
        total: number;
        page: number;
        limit: number;
    }>>;
    warehouses(): Promise<ApiResponse<import("./entities").Warehouse[]>>;
    createWarehouse(dto: any): Promise<ApiResponse<import("./entities").Warehouse>>;
    xntReport(from: string, to: string, wid?: string): Promise<ApiResponse<{
        period: {
            from: Date;
            to: Date;
        };
        warehouseId: number | undefined;
        items: {
            closingQty: number;
            productId: number;
            openingQty: number;
            importQty: number;
            exportQty: number;
        }[];
    }>>;
    expiringProducts(days?: string): Promise<ApiResponse<{
        thresholdDays: number;
        thresholdDate: Date;
        items: any;
        totalExpiringBatches: any;
    }>>;
}
export declare class PurchaseOrderController {
    private svc;
    constructor(svc: InventoryService);
    findAll(page?: string, limit?: string): Promise<ApiResponse<{
        items: import("./entities").PurchaseOrder[];
        total: number;
        page: number;
        limit: number;
    }>>;
    create(dto: any): Promise<ApiResponse<import("./entities").PurchaseOrder>>;
}
export declare class StockTakeController {
    private svc;
    constructor(svc: InventoryService);
    create(dto: any): Promise<ApiResponse<import("./entities").StockTake>>;
}
