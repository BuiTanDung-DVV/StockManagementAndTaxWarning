import { InventoryStock, InventoryMovement, Warehouse, PurchaseOrder, StockTake } from '../inventory/entities';
export declare class InventoryService {
    private stockRepo;
    private movementRepo;
    private warehouseRepo;
    private poRepo;
    private poItemRepo;
    private stockTakeRepo;
    private stockTakeItemRepo;
    getStock(page?: number, limit?: number): Promise<{
        items: InventoryStock[];
        total: number;
        page: number;
        limit: number;
        totalPages: number;
    }>;
    getLowStock(): Promise<InventoryStock[]>;
    getMovements(page?: number, limit?: number): Promise<{
        items: InventoryMovement[];
        total: number;
        page: number;
        limit: number;
        totalPages: number;
    }>;
    getWarehouses(): Promise<Warehouse[]>;
    createWarehouse(dto: Partial<Warehouse>): Promise<Warehouse>;
    getXntReport(): Promise<never[]>;
    getExpiringProducts(): Promise<never[]>;
    getPurchaseOrders(page?: number, limit?: number): Promise<{
        items: PurchaseOrder[];
        total: number;
        page: number;
        limit: number;
        totalPages: number;
    }>;
    createPurchaseOrder(dto: any): Promise<PurchaseOrder[]>;
    createStockTake(dto: any): Promise<StockTake[]>;
}
