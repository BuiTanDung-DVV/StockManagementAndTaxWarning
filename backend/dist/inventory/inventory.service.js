"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.InventoryService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const entities_1 = require("./entities");
let InventoryService = class InventoryService {
    constructor(stockRepo, movementRepo, poRepo, poItemRepo, stockTakeRepo, stockTakeItemRepo, warehouseRepo) {
        this.stockRepo = stockRepo;
        this.movementRepo = movementRepo;
        this.poRepo = poRepo;
        this.poItemRepo = poItemRepo;
        this.stockTakeRepo = stockTakeRepo;
        this.stockTakeItemRepo = stockTakeItemRepo;
        this.warehouseRepo = warehouseRepo;
    }
    async getCurrentStock(warehouseId) {
        const qb = this.stockRepo.createQueryBuilder('s').where('s.quantity > 0');
        if (warehouseId)
            qb.andWhere('s.warehouseId = :wid', { wid: warehouseId });
        return qb.getMany();
    }
    async getLowStock(threshold) {
        return this.stockRepo.createQueryBuilder('s')
            .where('s.quantity <= :threshold', { threshold: threshold || 10 })
            .getMany();
    }
    async getMovements(productId, page = 1, limit = 20) {
        const qb = this.movementRepo.createQueryBuilder('m').orderBy('m.createdAt', 'DESC');
        if (productId)
            qb.where('m.productId = :pid', { pid: productId });
        const [items, total] = await qb.skip((page - 1) * limit).take(limit).getManyAndCount();
        return { items, total, page, limit };
    }
    async createPurchaseOrder(dto) {
        const orderCode = 'NK' + Date.now().toString().slice(-8);
        let subtotal = 0;
        const items = dto.items.map(i => {
            const sub = i.quantity * i.unitPrice;
            subtotal += sub;
            return this.poItemRepo.create({ product: { id: i.productId }, quantity: i.quantity, unitPrice: i.unitPrice, subtotal: sub });
        });
        const po = this.poRepo.create({ orderCode, supplierId: dto.supplierId, orderDate: new Date(), subtotal, totalAmount: subtotal, notes: dto.notes, items });
        return this.poRepo.save(po);
    }
    async findPurchaseOrders(page = 1, limit = 20) {
        const [items, total] = await this.poRepo.findAndCount({
            relations: ['items', 'items.product'], skip: (page - 1) * limit, take: limit, order: { createdAt: 'DESC' },
        });
        return { items, total, page, limit };
    }
    async createStockTake(dto) {
        const code = 'KK' + Date.now().toString().slice(-8);
        const items = dto.items.map(i => this.stockTakeItemRepo.create({
            product: { id: i.productId }, systemQty: i.systemQty, actualQty: i.actualQty, difference: i.actualQty - i.systemQty, notes: i.notes,
        }));
        return this.stockTakeRepo.save(this.stockTakeRepo.create({ stockTakeCode: code, stockTakeDate: new Date(), notes: dto.notes, items }));
    }
    async findWarehouses() { return this.warehouseRepo.find({ where: { isActive: true } }); }
    async createWarehouse(dto) { return this.warehouseRepo.save(this.warehouseRepo.create(dto)); }
    async getXNTReport(from, to, warehouseId) {
        const openingQb = this.movementRepo.createQueryBuilder('m')
            .select('m.productId', 'productId')
            .addSelect(`SUM(CASE WHEN m.movementType IN ('IN','RETURN') THEN m.quantity ELSE -m.quantity END)`, 'openingQty')
            .where('m.createdAt < :from', { from });
        if (warehouseId)
            openingQb.andWhere('m.warehouseId = :wid', { wid: warehouseId });
        openingQb.groupBy('m.productId');
        const openingData = await openingQb.getRawMany();
        const importQb = this.movementRepo.createQueryBuilder('m')
            .select('m.productId', 'productId')
            .addSelect('COALESCE(SUM(m.quantity), 0)', 'importQty')
            .where(`m.movementType IN ('IN','RETURN')`)
            .andWhere('m.createdAt BETWEEN :from AND :to', { from, to });
        if (warehouseId)
            importQb.andWhere('m.warehouseId = :wid', { wid: warehouseId });
        importQb.groupBy('m.productId');
        const importData = await importQb.getRawMany();
        const exportQb = this.movementRepo.createQueryBuilder('m')
            .select('m.productId', 'productId')
            .addSelect('COALESCE(SUM(m.quantity), 0)', 'exportQty')
            .where(`m.movementType IN ('OUT','ADJUSTMENT')`)
            .andWhere('m.createdAt BETWEEN :from AND :to', { from, to });
        if (warehouseId)
            exportQb.andWhere('m.warehouseId = :wid', { wid: warehouseId });
        exportQb.groupBy('m.productId');
        const exportData = await exportQb.getRawMany();
        const productMap = new Map();
        for (const row of openingData) {
            productMap.set(+row.productId, { productId: +row.productId, openingQty: +row.openingQty, importQty: 0, exportQty: 0, closingQty: 0 });
        }
        for (const row of importData) {
            const entry = productMap.get(+row.productId) || { productId: +row.productId, openingQty: 0, importQty: 0, exportQty: 0, closingQty: 0 };
            entry.importQty = +row.importQty;
            productMap.set(+row.productId, entry);
        }
        for (const row of exportData) {
            const entry = productMap.get(+row.productId) || { productId: +row.productId, openingQty: 0, importQty: 0, exportQty: 0, closingQty: 0 };
            entry.exportQty = +row.exportQty;
            productMap.set(+row.productId, entry);
        }
        const report = Array.from(productMap.values()).map(entry => ({
            ...entry,
            closingQty: entry.openingQty + entry.importQty - entry.exportQty,
        }));
        return { period: { from, to }, warehouseId, items: report };
    }
    async getExpiringProducts(daysAhead = 30) {
        const thresholdDate = new Date();
        thresholdDate.setDate(thresholdDate.getDate() + daysAhead);
        const results = await this.stockRepo.manager.query(`
            SELECT pb.id, pb.product_id as productId, pb.batch_number as batchNumber,
                   pb.expiry_date as expiryDate, pb.quantity, pb.cost_price as costPrice,
                   p.name as productName, p.sku,
                   DATEDIFF(day, GETDATE(), pb.expiry_date) as daysUntilExpiry
            FROM product_batches pb
            JOIN products p ON p.id = pb.product_id
            WHERE pb.expiry_date IS NOT NULL
              AND pb.expiry_date <= @0
              AND pb.quantity > 0
              AND pb.is_active = 1
            ORDER BY pb.expiry_date ASC
        `, [thresholdDate]);
        return {
            thresholdDays: daysAhead,
            thresholdDate,
            items: results,
            totalExpiringBatches: results.length,
        };
    }
};
exports.InventoryService = InventoryService;
exports.InventoryService = InventoryService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(entities_1.InventoryStock)),
    __param(1, (0, typeorm_1.InjectRepository)(entities_1.InventoryMovement)),
    __param(2, (0, typeorm_1.InjectRepository)(entities_1.PurchaseOrder)),
    __param(3, (0, typeorm_1.InjectRepository)(entities_1.PurchaseOrderItem)),
    __param(4, (0, typeorm_1.InjectRepository)(entities_1.StockTake)),
    __param(5, (0, typeorm_1.InjectRepository)(entities_1.StockTakeItem)),
    __param(6, (0, typeorm_1.InjectRepository)(entities_1.Warehouse)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository])
], InventoryService);
//# sourceMappingURL=inventory.service.js.map