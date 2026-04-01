"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.InventoryService = void 0;
const db_config_1 = require("../config/db.config");
const entities_1 = require("../inventory/entities");
const entities_2 = require("../product/entities");
const cogs_service_1 = require("./cogs.service");
class InventoryService {
    constructor() {
        this.stockRepo = db_config_1.AppDataSource.getRepository(entities_1.InventoryStock);
        this.movementRepo = db_config_1.AppDataSource.getRepository(entities_1.InventoryMovement);
        this.warehouseRepo = db_config_1.AppDataSource.getRepository(entities_1.Warehouse);
        this.poRepo = db_config_1.AppDataSource.getRepository(entities_1.PurchaseOrder);
        this.poItemRepo = db_config_1.AppDataSource.getRepository(entities_1.PurchaseOrderItem);
        this.stockTakeRepo = db_config_1.AppDataSource.getRepository(entities_1.StockTake);
        this.stockTakeItemRepo = db_config_1.AppDataSource.getRepository(entities_1.StockTakeItem);
        this.batchRepo = db_config_1.AppDataSource.getRepository(entities_2.ProductBatch);
        this.cogsService = new cogs_service_1.COGSService();
    }
    async getStock(page = 1, limit = 20) {
        const [items, total] = await this.stockRepo.findAndCount({
            skip: (page - 1) * limit,
            take: limit,
            relations: ['product', 'warehouse']
        });
        return { items, total, page, limit, totalPages: Math.ceil(total / limit) };
    }
    async getLowStock(threshold) {
        const query = this.stockRepo.createQueryBuilder('s');
        if (threshold !== undefined && !isNaN(threshold)) {
            query.where('s.quantity <= :threshold', { threshold });
        }
        else {
            query.innerJoin(entities_2.Product, 'p', 'p.id = s.productId')
                .where('s.quantity <= p.min_stock');
        }
        return query.getMany();
    }
    async getMovements(page = 1, limit = 20) {
        const [items, total] = await this.movementRepo.findAndCount({ skip: (page - 1) * limit, take: limit, order: { createdAt: 'DESC' } });
        return { items, total, page, limit, totalPages: Math.ceil(total / limit) };
    }
    async getWarehouses() { return this.warehouseRepo.find(); }
    async createWarehouse(dto) { return this.warehouseRepo.save(this.warehouseRepo.create(dto)); }
    async getXntReport(from, to, warehouseId) {
        const fromDate = from ? new Date(from) : new Date(new Date().getFullYear(), new Date().getMonth(), 1);
        const toDate = to ? new Date(to) : new Date();
        toDate.setHours(23, 59, 59, 999);
        const qb = db_config_1.AppDataSource.getRepository(entities_2.Product).createQueryBuilder('p')
            .select(['p.id as id', 'p.sku as sku', 'p.name as name'])
            .leftJoin('inventory_movements', 'm', 'p.id = m.product_id' + (warehouseId ? ' AND m.warehouse_id = :warehouseId' : ''))
            .leftJoin('inventory_stocks', 's', 'p.id = s.product_id' + (warehouseId ? ' AND s.warehouse_id = :warehouseId' : ''))
            .addSelect(`COALESCE(SUM(CASE WHEN m.created_at < :from AND m.movement_type IN ('IN', 'RETURN') THEN m.quantity WHEN m.created_at < :from AND m.movement_type = 'OUT' THEN -m.quantity ELSE 0 END), 0)`, 'startQty')
            .addSelect(`COALESCE(SUM(CASE WHEN m.created_at >= :from AND m.created_at <= :to AND m.movement_type IN ('IN', 'RETURN') THEN m.quantity ELSE 0 END), 0)`, 'importQty')
            .addSelect(`COALESCE(SUM(CASE WHEN m.created_at >= :from AND m.created_at <= :to AND m.movement_type = 'OUT' THEN m.quantity ELSE 0 END), 0)`, 'exportQty')
            .addSelect('COALESCE(MAX(s.quantity), 0)', 'endQty')
            .groupBy('p.id')
            .addGroupBy('p.sku')
            .addGroupBy('p.name')
            .setParameters({ from: fromDate, to: toDate, warehouseId });
        return qb.getRawMany();
    }
    async getExpiringProducts(daysAhead = 30) {
        const targetDate = new Date();
        targetDate.setDate(targetDate.getDate() + daysAhead);
        return this.batchRepo.createQueryBuilder('b')
            .innerJoinAndSelect('b.product', 'p')
            .where('b.expiry_date IS NOT NULL')
            .andWhere('b.expiry_date <= :targetDate', { targetDate })
            .andWhere('b.quantity > 0')
            .orderBy('b.expiry_date', 'ASC')
            .getMany();
    }
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
        const savedPO = await this.poRepo.save(po);
        for (const item of (dto.items || [])) {
            if (item.productId && item.quantity > 0 && item.unitPrice > 0) {
                await this.cogsService.addInventoryLot({
                    productId: Number(item.productId),
                    quantity: Number(item.quantity),
                    costPrice: Number(item.unitPrice),
                    purchaseId: savedPO.id,
                    notes: `PO ${savedPO.orderCode}`,
                });
            }
        }
        return savedPO;
    }
    async createStockTake(dto) {
        const items = (dto.items || []).map((i) => this.stockTakeItemRepo.create({
            product: { id: i.productId },
            systemQty: i.systemQty || 0,
            actualQty: i.actualQty || 0,
            difference: (i.actualQty || 0) - (i.systemQty || 0),
            notes: i.notes
        }));
        return this.stockTakeRepo.save(this.stockTakeRepo.create({ ...dto, items }));
    }
}
exports.InventoryService = InventoryService;
//# sourceMappingURL=inventory.service.js.map