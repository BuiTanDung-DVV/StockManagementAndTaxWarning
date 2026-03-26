"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.InventoryService = void 0;
const db_config_1 = require("../config/db.config");
const entities_1 = require("../inventory/entities");
class InventoryService {
    constructor() {
        this.stockRepo = db_config_1.AppDataSource.getRepository(entities_1.InventoryStock);
        this.movementRepo = db_config_1.AppDataSource.getRepository(entities_1.InventoryMovement);
        this.warehouseRepo = db_config_1.AppDataSource.getRepository(entities_1.Warehouse);
        this.poRepo = db_config_1.AppDataSource.getRepository(entities_1.PurchaseOrder);
        this.poItemRepo = db_config_1.AppDataSource.getRepository(entities_1.PurchaseOrderItem);
        this.stockTakeRepo = db_config_1.AppDataSource.getRepository(entities_1.StockTake);
        this.stockTakeItemRepo = db_config_1.AppDataSource.getRepository(entities_1.StockTakeItem);
    }
    async getStock(page = 1, limit = 20) {
        const [items, total] = await this.stockRepo.findAndCount({ skip: (page - 1) * limit, take: limit });
        return { items, total, page, limit, totalPages: Math.ceil(total / limit) };
    }
    async getLowStock() {
        return this.stockRepo.createQueryBuilder('s').where('s.quantity <= s.minQuantity').getMany();
    }
    async getMovements(page = 1, limit = 20) {
        const [items, total] = await this.movementRepo.findAndCount({ skip: (page - 1) * limit, take: limit, order: { createdAt: 'DESC' } });
        return { items, total, page, limit, totalPages: Math.ceil(total / limit) };
    }
    async getWarehouses() { return this.warehouseRepo.find(); }
    async createWarehouse(dto) { return this.warehouseRepo.save(this.warehouseRepo.create(dto)); }
    async getXntReport() { return []; }
    async getExpiringProducts() { return []; }
    async getPurchaseOrders(page = 1, limit = 20) {
        const [items, total] = await this.poRepo.findAndCount({ skip: (page - 1) * limit, take: limit, order: { orderDate: 'DESC' } });
        return { items, total, page, limit, totalPages: Math.ceil(total / limit) };
    }
    async createPurchaseOrder(dto) {
        let totalAmount = 0;
        const items = (dto.items || []).map((i) => {
            const sub = i.quantity * i.unitPrice;
            totalAmount += sub;
            return this.poItemRepo.create({ ...i, subtotal: sub });
        });
        const po = this.poRepo.create({ ...dto, orderCode: 'PO' + Date.now().toString().slice(-6), totalAmount, items });
        return this.poRepo.save(po);
    }
    async createStockTake(dto) {
        const items = (dto.items || []).map((i) => this.stockTakeItemRepo.create({ ...i, expectedQuantity: 0, difference: i.actualQuantity }));
        return this.stockTakeRepo.save(this.stockTakeRepo.create({ ...dto, items }));
    }
}
exports.InventoryService = InventoryService;
//# sourceMappingURL=inventory.service.js.map