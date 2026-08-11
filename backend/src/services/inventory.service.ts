import { AppDataSource } from '../config/db.config';
import { InventoryStock, InventoryMovement, Warehouse, PurchaseOrder, PurchaseOrderItem, StockTake, StockTakeItem } from '../inventory/entities';
import { Product, ProductBatch } from '../product/entities';
import { COGSService } from './cogs.service';
import { PostingService } from './posting.service';
import { EntityManager } from 'typeorm';
import {
    resolveCurrentMonthExpensePeriod,
    vietnamDateKey,
} from '../finance/finance-period.utils';
import { buildAllocatedMerchandiseRevenueSql } from '../sales/sales-accounting.utils';
import { classifyInventoryAbc } from '../inventory/inventory-abc.utils';

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
    private postingService = new PostingService();

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
    async getLowStock(shopId: number | number[], threshold?: number) {
        const isArray = Array.isArray(shopId);
        const shopCondition = isArray ? 's.shop_id IN (:...shopIds)' : 's.shop_id = :shopId';
        const shopParams = isArray ? { shopIds: shopId } : { shopId };

        const query = this.stockRepo.createQueryBuilder('s')
            .leftJoinAndSelect('s.product', 'p')
            .where(shopCondition, shopParams);
            
        if (threshold !== undefined && !isNaN(threshold)) {
            query.andWhere('s.quantity <= :threshold', { threshold });
        } else {
            query.andWhere('s.quantity <= p.min_stock');
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

    async getCategoriesSummary(shopId: number | number[]) {
        const isArray = Array.isArray(shopId);
        const shopCondition = isArray ? 's.shop_id = ANY($1)' : 's.shop_id = $1';

        const query = `
            SELECT 
                COALESCE(c.name, 'Chưa phân loại') as name,
                COUNT(DISTINCT p.id) as sku_count,
                COALESCE(SUM(s.quantity * p.cost_price), 0) as value
            FROM inventory_stocks s
            JOIN products p ON s.product_id = p.id
            LEFT JOIN categories c ON p.category_id = c.id
            WHERE ${shopCondition} AND s.quantity > 0
            GROUP BY c.id, c.name
            ORDER BY value DESC
        `;
        const result = await AppDataSource.query(query, [isArray ? shopId : shopId]);
        return result.map((r: any) => ({
            name: r.name,
            skuCount: Number(r.sku_count),
            value: Number(r.value)
        }));
    }

    // Reports
    async getXntReport(shopId: number, from?: string, to?: string, warehouseId?: number) {
        const fromDate = from ? new Date(from) : new Date(new Date().getFullYear(), new Date().getMonth(), 1);
        const toDate = to ? new Date(to) : new Date();
        toDate.setHours(23, 59, 59, 999);

        const qb = AppDataSource.getRepository(Product).createQueryBuilder('p')
            .select(['p.id as id', 'p.sku as sku', 'p.name as name', 'p.unit as unit'])
            .where('p.shop_id = :shopId', { shopId })
            .leftJoin('inventory_movements', 'm', 'p.id = m.product_id AND m.shop_id = :shopId' + (warehouseId ? ' AND m.warehouse_id = :warehouseId' : ''))
            .addSelect(`COALESCE(SUM(CASE WHEN m.created_at < :from AND m.movement_type IN ('IN', 'RETURN') THEN m.quantity WHEN m.created_at < :from AND m.movement_type = 'OUT' THEN -m.quantity ELSE 0 END), 0)`, 'startQty')
            .addSelect(`COALESCE(SUM(CASE WHEN m.created_at >= :from AND m.created_at <= :to AND m.movement_type IN ('IN', 'RETURN') THEN m.quantity ELSE 0 END), 0)`, 'importQty')
            .addSelect(`COALESCE(SUM(CASE WHEN m.created_at >= :from AND m.created_at <= :to AND m.movement_type = 'OUT' THEN m.quantity ELSE 0 END), 0)`, 'exportQty')
            .addSelect(`COALESCE(SUM(CASE WHEN m.created_at <= :to AND m.movement_type IN ('IN', 'RETURN') THEN m.quantity WHEN m.created_at <= :to AND m.movement_type = 'OUT' THEN -m.quantity ELSE 0 END), 0)`, 'endQty')
            .groupBy('p.id')
            .addGroupBy('p.sku')
            .addGroupBy('p.name')
            .addGroupBy('p.unit')
            .setParameters({ from: fromDate, to: toDate, warehouseId, shopId });

        const rows = await qb.getRawMany();
        const items = rows.map((row) => ({
            id: Number(row.id),
            sku: row.sku,
            name: row.name,
            productName: row.name,
            unit: row.unit || 'Đơn vị',
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
            openingSkuCount: acc.openingSkuCount + (item.openingStock > 0 ? 1 : 0),
            importedSkuCount: acc.importedSkuCount + (item.totalImport > 0 ? 1 : 0),
            exportedSkuCount: acc.exportedSkuCount + (item.totalExport > 0 ? 1 : 0),
            closingSkuCount: acc.closingSkuCount + (item.closingStock > 0 ? 1 : 0),
        }), {
            // Legacy quantity totals are retained for API compatibility only.
            // They must not be presented as one comparable quantity when product
            // units differ (for example bao, mét, bộ and cái).
            openingStock: 0,
            totalImport: 0,
            totalExport: 0,
            closingStock: 0,
            openingSkuCount: 0,
            importedSkuCount: 0,
            exportedSkuCount: 0,
            closingSkuCount: 0,
        });

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
            .innerJoin(
                'inventory_stocks',
                's',
                's.product_id = p.id AND s.shop_id = p.shop_id',
            )
            .where('p.shop_id = :shopId', { shopId })
            .andWhere('s.quantity > 0')
            .andWhere((qb) => {
                const subQuery = qb.subQuery()
                    .select('sold_item.product_id')
                    .from('sales_order_items', 'sold_item')
                    .innerJoin(
                        'sales_orders',
                        'sold_order',
                        'sold_order.id = sold_item.order_id',
                    )
                    .where('sold_order.shop_id = :shopId')
                    .andWhere("sold_order.status != 'CANCELLED'")
                    .andWhere('sold_order.order_date >= :cutoff', { cutoff: cutoffDate })
                    .getQuery();
                return 'p.id NOT IN ' + subQuery;
            })
            .select([
                'p.id as id',
                'p.sku as sku',
                'p.name as name',
                'p.unit as unit',
            ])
            .addSelect('SUM(s.quantity)', 'currentStock')
            .addSelect(`(
                SELECT MAX(last_order.order_date)
                FROM sales_order_items last_item
                JOIN sales_orders last_order ON last_order.id = last_item.order_id
                WHERE last_item.product_id = p.id
                  AND last_order.shop_id = :shopId
                  AND last_order.status != 'CANCELLED'
            )`, 'lastSoldAt')
            .groupBy('p.id')
            .addGroupBy('p.sku')
            .addGroupBy('p.name')
            .addGroupBy('p.unit')
            .getRawMany();

        const now = Date.now();
        return result.map((row: any) => {
            const lastSoldAt = row.lastSoldAt ? new Date(row.lastSoldAt) : null;
            const daysSinceLastSale = lastSoldAt && !Number.isNaN(lastSoldAt.getTime())
                ? Math.max(0, Math.floor((now - lastSoldAt.getTime()) / 86_400_000))
                : null;
            return {
                id: Number(row.id),
                sku: row.sku,
                name: row.name,
                productName: row.name,
                unit: row.unit || 'Đơn vị',
                currentStock: Number(row.currentStock || 0),
                currentQuantity: Number(row.currentStock || 0),
                lastSoldAt: lastSoldAt?.toISOString() || null,
                daysSinceLastSale,
            };
        });
    }

    async getAbcAnalysis(shopId: number | number[], from?: string, to?: string) {
        const { fromDate, toDate } = resolveCurrentMonthExpensePeriod(from, to);
        const fromKey = vietnamDateKey(fromDate);
        const toKey = vietnamDateKey(toDate);
        const isArray = Array.isArray(shopId);
        const productShopCondition = isArray ? 'p.shop_id = ANY($1)' : 'p.shop_id = $1';
        const orderShopCondition = isArray ? 'o.shop_id = ANY($1)' : 'o.shop_id = $1';
        const returnShopCondition = isArray ? 'r.shop_id = ANY($1)' : 'r.shop_id = $1';
        const soldNetValueSql = buildAllocatedMerchandiseRevenueSql('oi.subtotal', 'o');
        const returnedNetValueSql = buildAllocatedMerchandiseRevenueSql(
            'ri.subtotal',
            'returned_order',
        );

        const rows = await AppDataSource.query(`
            WITH stock AS (
                SELECT
                    s.product_id,
                    SUM(GREATEST(s.quantity, 0)) AS current_stock
                FROM inventory_stocks s
                WHERE ${isArray ? 's.shop_id = ANY($1)' : 's.shop_id = $1'}
                GROUP BY s.product_id
            ), sold AS (
                SELECT
                    oi.product_id,
                    SUM(${soldNetValueSql}) AS gross_revenue,
                    SUM(oi.quantity) AS gross_quantity
                FROM sales_order_items oi
                JOIN sales_orders o ON o.id = oi.order_id
                WHERE ${orderShopCondition}
                  AND o.order_date >= $2::date
                  AND o.order_date < ($3::date + interval '1 day')
                  AND o.status != 'CANCELLED'
                GROUP BY oi.product_id
            ), returned AS (
                SELECT
                    ri.product_id,
                    SUM(${returnedNetValueSql}) AS return_revenue,
                    SUM(ri.quantity) AS return_quantity
                FROM sales_return_items ri
                JOIN sales_returns r ON r.id = ri.return_id
                JOIN sales_orders returned_order ON returned_order.id = r.order_id
                WHERE ${returnShopCondition}
                  AND r.return_date >= $2::date
                  AND r.return_date < ($3::date + interval '1 day')
                  AND UPPER(COALESCE(r.status, '')) NOT IN ('CANCELLED', 'REJECTED')
                GROUP BY ri.product_id
            )
            SELECT
                p.id,
                p.sku,
                p.name,
                COALESCE(p.unit, 'Sản phẩm') AS unit,
                COALESCE(c.name, 'Chưa phân loại') AS category,
                COALESCE(sold.gross_revenue, 0) - COALESCE(returned.return_revenue, 0)
                    AS revenue,
                COALESCE(sold.gross_quantity, 0) - COALESCE(returned.return_quantity, 0)
                    AS quantity_sold,
                COALESCE(stock.current_stock, 0) AS current_stock,
                COALESCE(stock.current_stock, 0) * COALESCE(p.cost_price, 0) AS stock_value
            FROM products p
            LEFT JOIN categories c ON c.id = p.category_id
            LEFT JOIN stock ON stock.product_id = p.id
            LEFT JOIN sold ON sold.product_id = p.id
            LEFT JOIN returned ON returned.product_id = p.id
            WHERE ${productShopCondition}
            ORDER BY revenue DESC, p.id ASC
        `, [shopId, fromKey, toKey]);

        const analysis = classifyInventoryAbc(rows.map((row: any) => ({
            id: Number(row.id),
            sku: row.sku,
            name: row.name,
            unit: row.unit,
            category: row.category,
            revenue: Number(row.revenue || 0),
            quantitySold: Number(row.quantity_sold || 0),
            currentStock: Number(row.current_stock || 0),
            stockValue: Number(row.stock_value || 0),
        })));

        return {
            ...analysis,
            period: {
                from: fromKey,
                to: toKey,
            },
            timezone: 'Asia/Ho_Chi_Minh',
            definition: 'Phân nhóm theo tỷ trọng doanh thu hàng hóa thuần chưa VAT, sau chiết khấu và hàng trả trong kỳ. SKU có hàng trả vượt bán được loại khỏi mẫu số ABC và công khai thành khoản điều chỉnh.',
        };
    }


    // Purchase Orders
    async getPurchaseOrders(shopId: number, page = 1, limit = 20) {
        const [items, total] = await this.poRepo.findAndCount({ 
            where: { shopId }, 
            skip: (page - 1) * limit, 
            take: limit, 
            order: { orderDate: 'DESC' },
            relations: ['items', 'items.product', 'supplier']
        });
        return { items, total, page, limit, totalPages: Math.ceil(total / limit) };
    }
    async createPurchaseOrder(shopId: number, dto: any) {
        const queryRunner = AppDataSource.createQueryRunner();
        await queryRunner.connect();
        await queryRunner.startTransaction();

        try {
            const manager = queryRunner.manager;

            const targetWarehouseId = dto.warehouseId
                ? Number(dto.warehouseId)
                : await this.ensureDefaultWarehouseId(shopId, manager);
            await this.assertWarehouseBelongsToShop(shopId, targetWarehouseId, manager);

            let totalAmount = 0;
            const items = (dto.items || []).map((i: any) => {
                const sub = i.quantity * i.unitPrice;
                totalAmount += sub;
                return manager.create(PurchaseOrderItem, { ...i, subtotal: sub, shopId });
            });

            const po = manager.create(PurchaseOrder, { ...dto, warehouseId: targetWarehouseId, orderCode: 'PO' + Date.now().toString().slice(-6), totalAmount, items, shopId, status: 'PENDING' });
            const savedPO = await manager.save(PurchaseOrder, po);

            await queryRunner.commitTransaction();
            return savedPO;
        } catch (error) {
            await queryRunner.rollbackTransaction();
            throw error;
        } finally {
            await queryRunner.release();
        }
    }

    async updatePurchaseOrder(shopId: number, id: number, dto: any) {
        const queryRunner = AppDataSource.createQueryRunner();
        await queryRunner.connect();
        await queryRunner.startTransaction();

        try {
            const manager = queryRunner.manager;
            const po = await manager.findOne(PurchaseOrder, { 
                where: { id, shopId },
                relations: ['items'] 
            });
            if (!po) throw new Error('PurchaseOrder not found');

            const currentStatus = String(po.status || 'PENDING').toUpperCase();
            const nextStatus = dto.status
                ? String(dto.status).toUpperCase()
                : currentStatus;
            if (!['PENDING', 'COMPLETED', 'CANCELLED'].includes(nextStatus)) {
                throw new Error('Validation: Invalid purchase order status');
            }
            if (currentStatus !== 'PENDING') {
                const isIdempotentStatusUpdate =
                    Object.keys(dto).every((key) => key === 'status') &&
                    nextStatus === currentStatus;
                if (isIdempotentStatusUpdate) {
                    await queryRunner.commitTransaction();
                    return po;
                }
                throw new Error('Validation: Completed or cancelled purchase order is immutable');
            }

            if (dto.warehouseId) {
                await this.assertWarehouseBelongsToShop(shopId, Number(dto.warehouseId), manager);
                po.warehouseId = Number(dto.warehouseId);
            }

            // If changing status from PENDING to COMPLETED, increase stock and post journal
            if (nextStatus === 'COMPLETED') {
                for (const item of (po.items || [])) {
                    if (item.productId && item.quantity > 0 && item.unitPrice > 0) {
                        await this.cogsService.addInventoryLot({
                            productId: Number(item.productId),
                            quantity: Number(item.quantity),
                            costPrice: Number(item.unitPrice),
                            purchaseId: po.id,
                            notes: `PO ${po.orderCode}`,
                            shopId,
                        }, manager);
                        await this.increaseStock(
                            shopId,
                            Number(item.productId),
                            po.warehouseId,
                            Number(item.quantity),
                            po.id,
                            manager
                        );
                    }
                }
                
                if (po.totalAmount > 0) {
                    await this.postingService.postJournal(
                        shopId,
                        'PURCHASE_ORDER',
                        po.id,
                        `Nhập kho - Đơn ${po.orderCode}`,
                        [
                            { accountCode: '156', amount: po.totalAmount, entryType: 'DEBIT' },
                            { accountCode: '331', amount: po.totalAmount, entryType: 'CREDIT' },
                        ],
                        manager
                    );
                }
            }

            po.status = nextStatus;
            const saved = await manager.save(PurchaseOrder, po);

            await queryRunner.commitTransaction();
            return saved;
        } catch (error) {
            await queryRunner.rollbackTransaction();
            throw error;
        } finally {
            await queryRunner.release();
        }
    }

    // updatePurchaseOrder is replaced above

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
        
        let warehouseId = dto.warehouseId;
        if (!warehouseId) {
            warehouseId = await this.ensureDefaultWarehouseId(shopId);
        }

        return this.stockTakeRepo.save(this.stockTakeRepo.create({ ...dto, warehouseId, items, shopId }));
    }

    async updateStockTake(shopId: number, id: number, dto: any) {
        const queryRunner = AppDataSource.createQueryRunner();
        await queryRunner.connect();
        await queryRunner.startTransaction();

        try {
            const manager = queryRunner.manager;
            const stockTake = await manager.findOne(StockTake, { where: { id, shopId }, relations: ['items', 'items.product'] });
            if (!stockTake) throw new Error('StockTake not found');
            
            if (dto.status === 'COMPLETED' && stockTake.status !== 'COMPLETED') {
                for (const item of (stockTake.items || [])) {
                    if (item.difference !== 0) {
                        const warehouseId = stockTake.warehouseId || await this.ensureDefaultWarehouseId(shopId, manager);
                        const productId = item.product?.id || (item as any).productId;
                        
                        let stock = await manager.findOne(InventoryStock, { where: { shopId, productId, warehouseId } as any });
                        if (!stock) {
                            stock = manager.create(InventoryStock, { shopId, productId, warehouseId, quantity: 0, updatedAt: new Date() });
                        }
                        
                        stock.quantity = Number(stock.quantity || 0) + Number(item.difference);
                        stock.updatedAt = new Date();
                        await manager.save(InventoryStock, stock);

                        await manager.save(InventoryMovement, manager.create(InventoryMovement, {
                            shopId,
                            productId,
                            warehouseId,
                            movementType: Number(item.difference) > 0 ? 'IN' : 'OUT',
                            quantity: Math.abs(Number(item.difference)),
                            referenceType: 'STOCK_TAKE',
                            referenceId: stockTake.id,
                            notes: `Kiểm kho phiếu #${stockTake.id}`,
                        }));
                    }
                }
            }

            stockTake.status = dto.status || stockTake.status;
            stockTake.notes = dto.notes !== undefined ? dto.notes : stockTake.notes;
            const saved = await manager.save(StockTake, stockTake);
            
            await queryRunner.commitTransaction();
            return saved;
        } catch (error) {
            await queryRunner.rollbackTransaction();
            throw error;
        } finally {
            await queryRunner.release();
        }
    }

    async deleteStockTake(shopId: number, id: number) {
        const stockTake = await this.stockTakeRepo.findOne({ where: { id, shopId } });
        if (stockTake) await this.stockTakeRepo.remove(stockTake);
        return { success: true };
    }

    private async assertWarehouseBelongsToShop(shopId: number, warehouseId: number, manager?: EntityManager) {
        const repo = manager ? manager.getRepository(Warehouse) : this.warehouseRepo;
        const warehouse = await repo.findOne({ where: { id: warehouseId, shopId, isActive: true } as any });
        if (!warehouse) throw new Error('Warehouse not found for shop');
    }

    private async ensureDefaultWarehouseId(shopId: number, manager?: EntityManager) {
        const repo = manager ? manager.getRepository(Warehouse) : this.warehouseRepo;
        let warehouse = await repo.findOne({ where: { shopId, isActive: true } as any });
        if (!warehouse) {
            warehouse = await repo.save(repo.create({
                name: `Kho mac dinh ${shopId}`,
                shopId,
                isActive: true,
            }));
        }
        return warehouse.id;
    }

    private async increaseStock(shopId: number, productId: number, warehouseId: number, quantity: number, purchaseOrderId: number, manager?: EntityManager) {
        const stockRepo = manager ? manager.getRepository(InventoryStock) : this.stockRepo;
        const movementRepo = manager ? manager.getRepository(InventoryMovement) : this.movementRepo;

        let stock = await stockRepo.findOne({ where: { shopId, productId, warehouseId } as any });
        if (!stock) {
            stock = stockRepo.create({ shopId, productId, warehouseId, quantity: 0, updatedAt: new Date() });
        }
        stock.quantity = Number(stock.quantity || 0) + quantity;
        stock.updatedAt = new Date();
        await stockRepo.save(stock);

        await movementRepo.save(movementRepo.create({
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
