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

        return qb.getRawMany();
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
        let totalAmount = 0;
        const items = (dto.items || []).map((i: any) => {
            const sub = i.quantity * i.unitPrice;
            totalAmount += sub;
            return this.poItemRepo.create({ ...i, subtotal: sub, shopId });
        });
        const po = this.poRepo.create({ ...dto, orderCode: 'PO' + Date.now().toString().slice(-6), totalAmount, items, shopId });
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
            }
        }

        return savedPO;
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
        return this.stockTakeRepo.save(this.stockTakeRepo.create({ ...dto, items, shopId }));
    }
}
