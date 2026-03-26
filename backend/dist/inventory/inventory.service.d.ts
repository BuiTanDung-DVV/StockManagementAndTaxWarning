import { Repository } from 'typeorm';
import { InventoryStock, InventoryMovement, PurchaseOrder, PurchaseOrderItem, StockTake, StockTakeItem, Warehouse } from './entities';
export declare class InventoryService {
    private stockRepo;
    private movementRepo;
    private poRepo;
    private poItemRepo;
    private stockTakeRepo;
    private stockTakeItemRepo;
    private warehouseRepo;
    constructor(stockRepo: Repository<InventoryStock>, movementRepo: Repository<InventoryMovement>, poRepo: Repository<PurchaseOrder>, poItemRepo: Repository<PurchaseOrderItem>, stockTakeRepo: Repository<StockTake>, stockTakeItemRepo: Repository<StockTakeItem>, warehouseRepo: Repository<Warehouse>);
    getCurrentStock(warehouseId?: number): Promise<InventoryStock[]>;
    getLowStock(threshold?: number): Promise<InventoryStock[]>;
    getMovements(productId?: number, page?: number, limit?: number): Promise<{
        items: InventoryMovement[];
        total: number;
        page: number;
        limit: number;
    }>;
    createPurchaseOrder(dto: {
        supplierId: number;
        items: {
            productId: number;
            quantity: number;
            unitPrice: number;
        }[];
        notes?: string;
    }): Promise<PurchaseOrder>;
    findPurchaseOrders(page?: number, limit?: number): Promise<{
        items: PurchaseOrder[];
        total: number;
        page: number;
        limit: number;
    }>;
    createStockTake(dto: {
        items: {
            productId: number;
            systemQty: number;
            actualQty: number;
            notes?: string;
        }[];
        notes?: string;
    }): Promise<StockTake>;
    findWarehouses(): Promise<Warehouse[]>;
    createWarehouse(dto: Partial<Warehouse>): Promise<Warehouse>;
    getXNTReport(from: Date, to: Date, warehouseId?: number): Promise<{
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
    }>;
    getExpiringProducts(daysAhead?: number): Promise<{
        thresholdDays: number;
        thresholdDate: Date;
        items: any;
        totalExpiringBatches: any;
    }>;
}
