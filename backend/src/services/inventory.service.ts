import { AppDataSource } from '../config/db.config';
import { InventoryStock, InventoryMovement, Warehouse, PurchaseOrder, PurchaseOrderItem, StockTake, StockTakeItem } from '../inventory/entities';
import { Product, ProductBatch } from '../product/entities';
import { COGSService } from './cogs.service';

export class InventoryService {
    private stockRepo = AppDataSource.getRepository(InventoryStock);
    private movementRepo = AppDataSource.getRepository(InventoryMovement);
    private warehouseRepo = AppDataSource.getRepository(Warehouse);
    private poRepo = AppDataSource.getRepository(PurchaseOrder);
    private poItemRepo = AppDataSource.getRepository(PurchaseOrderItem);
    private stockTakeRepo = AppDataSource.getRepository(StockTake);
    private stockTakeItemRepo = AppDataSource.getRepository(StockTakeItem);
    private batchRepo = AppDataSource.getRepository(ProductBatch);
    private cogsService = new COGSService();

    // Stock
    async getStock(shopId: number, page = 1, limit = 20) {
        const [items, total] = await this.stockRepo.findAndCount({ 
            where: { shopId },
            skip: (page - 1) * limit, 
            take: limit,
            relations: ['product', 'warehouse'] 
        });
        return { items, total, page, limit, totalPages: Math.ceil(total / limit) };
    }
    async getLowStock(shopId: number, threshold?: number) {
        const query = this.stockRepo.createQueryBuilder('s')
            .where('s.shop_id = :shopId', { shopId });
            
        if (threshold !== undefined && !isNaN(threshold)) {
            query.andWhere('s.quantity <= :threshold', { threshold });
        } else {
            query.innerJoin(Product, 'p', 'p.id = s.product_id')
                 .andWhere('s.quantity <= p.min_stock'); // typeorm uses db column name in raw builder if not mapped as property on s
        }
        return query.getMany();
    }
    
    // Movements
    async getMovements(shopId: number, page = 1, limit = 20) {
        const [items, total] = await this.movementRepo.findAndCount({ where: { shopId }, skip: (page - 1) * limit, take: limit, order: { createdAt: 'DESC' } });
        return { items, total, page, limit, totalPages: Math.ceil(total / limit) };
    }

    // Warehouses
    async getWarehouses(shopId: number) { return this.warehouseRepo.find({ where: { shopId } }); }
    async createWarehouse(shopId: number, dto: Partial<Warehouse>) { return this.warehouseRepo.save(this.warehouseRepo.create({ ...dto, shopId })); }

    // Reports
    async getXntReport(shopId: number, from?: string, to?: string, warehouseId?: number) {
        const fromDate = from ? new Date(from) : new Date(new Date().getFullYear(), new Date().getMonth(), 1);
        const toDate = to ? new Date(to) : new Date();
        toDate.setHours(23, 59, 59, 999);

        const qb = AppDataSource.getRepository(Product).createQueryBuilder('p')
            .select(['p.id as id', 'p.sku as sku', 'p.name as name'])
            .where('p.shop_id = :shopId', { shopId })
            .leftJoin('inventory_movements', 'm', 'p.id = m.product_id AND m.shop_id = :shopId' + (warehouseId ? ' AND m.warehouse_id = :warehouseId' : ''))
            .addSelect(`COALESCE(SUM(CASE WHEN m.created_at < :from AND m.movement_type IN ('IN', 'RETURN') THEN m.quantity WHEN m.created_at < :from AND m.movement_type = 'OUT' THEN -m.quantity ELSE 0 END), 0)`, 'startQty')
            .addSelect(`COALESCE(SUM(CASE WHEN m.created_at >= :from AND m.created_at <= :to AND m.movement_type IN ('IN', 'RETURN') THEN m.quantity ELSE 0 END), 0)`, 'importQty')
            .addSelect(`COALESCE(SUM(CASE WHEN m.created_at >= :from AND m.created_at <= :to AND m.movement_type = 'OUT' THEN m.quantity ELSE 0 END), 0)`, 'exportQty')
            .addSelect(`COALESCE(SUM(CASE WHEN m.created_at <= :to AND m.movement_type IN ('IN', 'RETURN') THEN m.quantity WHEN m.created_at <= :to AND m.movement_type = 'OUT' THEN -m.quantity ELSE 0 END), 0)`, 'endQty')
            .groupBy('p.id')
            .addGroupBy('p.sku')
            .addGroupBy('p.name')
            .setParameters({ from: fromDate, to: toDate, warehouseId, shopId });

        const rows = await qb.getRawMany();
        const items = rows.map((row) => ({
            id: Number(row.id),
            sku: row.sku,
            name: row.name,
            productName: row.name,
            openingStock: Number(row.startQty || 0),
            totalImport: Number(row.importQty || 0),
            imported: Number(row.importQty || 0),
            totalExport: Number(row.exportQty || 0),
            exported: Number(row.exportQty || 0),
            closingStock: Number(row.endQty || 0),
        }));
        const summary = items.reduce((acc, item) => ({
            openingStock: acc.openingStock + item.openingStock,
            totalImport: acc.totalImport + item.totalImport,
            totalExport: acc.totalExport + item.totalExport,
            closingStock: acc.closingStock + item.closingStock,
        }), { openingStock: 0, totalImport: 0, totalExport: 0, closingStock: 0 });

        return { items, summary, from: fromDate, to: toDate };
    }
    
    async getExpiringProducts(shopId: number, daysAhead: number = 30) {
        const targetDate = new Date();
        targetDate.setDate(targetDate.getDate() + daysAhead);
        
        return this.batchRepo.createQueryBuilder('b')
            .innerJoinAndSelect('b.product', 'p')
            .where('b.shop_id = :shopId', { shopId })
            .andWhere('b.expiry_date IS NOT NULL')
            .andWhere('b.expiry_date <= :targetDate', { targetDate })
            .andWhere('b.quantity > 0')
            .orderBy('b.expiry_date', 'ASC')
            .getMany();
    }

    async getSlowMovingProducts(shopId: number, daysUnsold: number = 30) {
        // Products that have stock but haven't been in any sales movement for daysUnsold days
        const cutoffDate = new Date();
        cutoffDate.setDate(cutoffDate.getDate() - daysUnsold);

        const result = await AppDataSource.getRepository('products')
            .createQueryBuilder('p')
            .innerJoin('inventory_stocks', 's', 's.product_id = p.id')
            .where('p.shop_id = :shopId', { shopId })
            .andWhere('s.quantity > 0')
            .andWhere((qb) => {
                const subQuery = qb.subQuery()
                    .select('m.product_id')
                    .from('inventory_movements', 'm')
                    .where("m.movement_type = 'OUT'")
                    .andWhere('m.created_at >= :cutoff', { cutoff: cutoffDate })
                    .getQuery();
                return 'p.id NOT IN ' + subQuery;
            })
            .select(['p.id as id', 'p.sku as sku', 'p.name as name'])
            .addSelect('SUM(s.quantity)', 'currentStock')
            .groupBy('p.id')
            .addGroupBy('p.sku')
            .addGroupBy('p.name')
            .getRawMany();

        return result;
    }


    // Purchase Orders
    async getPurchaseOrders(shopId: number, page = 1, limit = 20) {
        const [items, total] = await this.poRepo.findAndCount({ where: { shopId }, skip: (page - 1) * limit, take: limit, order: { orderDate: 'DESC' } });
        return { items, total, page, limit, totalPages: Math.ceil(total / limit) };
    }
    async createPurchaseOrder(shopId: number, dto: any) {
        const targetWarehouseId = dto.warehouseId
            ? Number(dto.warehouseId)
            : await this.ensureDefaultWarehouseId(shopId);
        await this.assertWarehouseBelongsToShop(shopId, targetWarehouseId);
        let totalAmount = 0;
        const items = (dto.items || []).map((i: any) => {
            const sub = i.quantity * i.unitPrice;
            totalAmount += sub;
            return this.poItemRepo.create({ ...i, subtotal: sub, shopId });
        });
        const po = this.poRepo.create({ ...dto, warehouseId: targetWarehouseId, orderCode: 'PO' + Date.now().toString().slice(-6), totalAmount, items, shopId });
        const savedPO = await this.poRepo.save(po) as unknown as PurchaseOrder;

        // Tạo inventory lots cho mỗi item (để COGS tính đúng)
        for (const item of (dto.items || [])) {
            if (item.productId && item.quantity > 0 && item.unitPrice > 0) {
                await this.cogsService.addInventoryLot({
                    productId: Number(item.productId),
                    quantity: Number(item.quantity),
                    costPrice: Number(item.unitPrice),
                    purchaseId: savedPO.id,
                    notes: `PO ${savedPO.orderCode}`,
                    shopId,
                });
                await this.increaseStock(
                    shopId,
                    Number(item.productId),
                    targetWarehouseId,
                    Number(item.quantity),
                    savedPO.id,
                );
            }
        }

        return savedPO;
    }

    async updatePurchaseOrder(shopId: number, id: number, dto: any) {
        const po = await this.poRepo.findOne({ where: { id, shopId } });
        if (!po) throw new Error('PurchaseOrder not found');
        if (dto.warehouseId) {
            await this.assertWarehouseBelongsToShop(shopId, Number(dto.warehouseId));
            po.warehouseId = Number(dto.warehouseId);
        }
        po.status = dto.status || po.status;
        return this.poRepo.save(po);
    }

    async deletePurchaseOrder(shopId: number, id: number) {
        const po = await this.poRepo.findOne({ where: { id, shopId } });
        if (po) await this.poRepo.remove(po);
        return { success: true };
    }

    // Stock Takes
    async getStockTakes(shopId: number, page = 1, limit = 20) {
        const [items, total] = await this.stockTakeRepo.findAndCount({ where: { shopId }, skip: (page - 1) * limit, take: limit, order: { id: 'DESC' } });
        return { items, total, page, limit, totalPages: Math.ceil(total / limit) };
    }
    async createStockTake(shopId: number, dto: any) {
        const items = (dto.items || []).map((i: any) => this.stockTakeItemRepo.create({
            product: { id: i.productId },
            systemQty: i.systemQty || 0,
            actualQty: i.actualQty || 0,
            difference: (i.actualQty || 0) - (i.systemQty || 0),
            notes: i.notes
        }));
        if (!dto.stockTakeDate && dto.takeDate) dto.stockTakeDate = dto.takeDate;
        return this.stockTakeRepo.save(this.stockTakeRepo.create({ ...dto, items, shopId }));
    }

    async updateStockTake(shopId: number, id: number, dto: any) {
        const stockTake = await this.stockTakeRepo.findOne({ where: { id, shopId }, relations: ['items'] });
        if (!stockTake) throw new Error('StockTake not found');
        stockTake.status = dto.status || stockTake.status;
        stockTake.notes = dto.notes !== undefined ? dto.notes : stockTake.notes;
        return this.stockTakeRepo.save(stockTake);
    }

    async deleteStockTake(shopId: number, id: number) {
        const stockTake = await this.stockTakeRepo.findOne({ where: { id, shopId } });
        if (stockTake) await this.stockTakeRepo.remove(stockTake);
        return { success: true };
    }

    private async assertWarehouseBelongsToShop(shopId: number, warehouseId: number) {
        const warehouse = await this.warehouseRepo.findOne({ where: { id: warehouseId, shopId, isActive: true } as any });
        if (!warehouse) throw new Error('Warehouse not found for shop');
    }

    private async ensureDefaultWarehouseId(shopId: number) {
        let warehouse = await this.warehouseRepo.findOne({ where: { shopId, isActive: true } as any });
        if (!warehouse) {
            warehouse = await this.warehouseRepo.save(this.warehouseRepo.create({
                name: `Kho mac dinh ${shopId}`,
                shopId,
                isActive: true,
            }));
        }
        return warehouse.id;
    }

    private async increaseStock(shopId: number, productId: number, warehouseId: number, quantity: number, purchaseOrderId: number) {
        let stock = await this.stockRepo.findOne({ where: { shopId, productId, warehouseId } as any });
        if (!stock) {
            stock = this.stockRepo.create({ shopId, productId, warehouseId, quantity: 0, updatedAt: new Date() });
        }
        stock.quantity = Number(stock.quantity || 0) + quantity;
        stock.updatedAt = new Date();
        await this.stockRepo.save(stock);

        await this.movementRepo.save(this.movementRepo.create({
            shopId,
            productId,
            warehouseId,
            movementType: 'IN',
            quantity,
            referenceType: 'PURCHASE_ORDER',
            referenceId: purchaseOrderId,
            notes: `Purchase order #${purchaseOrderId}`,
        }));
    }
}
