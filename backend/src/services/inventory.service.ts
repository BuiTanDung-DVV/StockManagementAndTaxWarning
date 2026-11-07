import { randomBytes } from 'crypto';
import { SupplierService } from './supplier.service';
import { openingEffectCents, openingEffectValue } from '../finance/opening-balance-effects.repository';
import { PurchaseWriteActor, PurchaseWriteError, requirePurchaseWriteAuthority, requireOpenPurchaseDay } from '../inventory/purchase-write-authorization';
import { withOrderDebtBalances } from '../finance/order-debt-balance.repository';
import { lockShopMutation } from '../utils/shop-mutation-lock';
import { AppDataSource } from '../config/db.config';
import { Invoice } from '../system/entities';
import { InventoryStock, InventoryMovement, Warehouse, PurchaseOrder, PurchaseOrderItem, StockTake, StockTakeItem } from '../inventory/entities';
import { Product, ProductBatch } from '../product/entities';
import { Supplier, Payable } from '../supplier/entities';
import { COGSService } from './cogs.service';
import { PostingService } from './posting.service';
import { Brackets, EntityManager, In, QueryRunner } from 'typeorm';
import { normalizePurchaseOrderQuery } from '../inventory/purchase-order-query.utils';
import { vietnameseSearchExpression, vietnameseSearchParams } from '../common/vietnamese-search.utils';
import {
    resolveCurrentMonthExpensePeriod,
    resolveVietnamBusinessDayEnd,
    vietnamDateKey,
} from '../finance/finance-period.utils';
import { buildAllocatedMerchandiseRevenueSql } from '../sales/sales-accounting.utils';
import { classifyInventoryAbc } from '../inventory/inventory-abc.utils';
import {
    normalizeStockTakeCreateInput,
    normalizeStockTakeStatusInput,
} from '../inventory/stock-take-input.utils';
import {
    normalizePurchaseOrderCreateInput,
    normalizePurchaseOrderUpdateInput,
} from '../inventory/purchase-order-input.utils';
import { normalizeWarehouseInput } from '../inventory/inventory-master-input.utils';
import { normalizeDatabaseBusinessDate } from '../system/data-freshness.utils';
import { normalizeXntExportQuery, summarizeXntExport, XntExportInputError } from '../inventory/xnt-export.utils';

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
    async getStock(shopId: number | number[], page = 1, limit = 20, warehouseId?: number) {
        const scopedShopId = Array.isArray(shopId) ? In(shopId) : shopId;
        const where = warehouseId
            ? { shopId: scopedShopId, warehouseId }
            : { shopId: scopedShopId };
        const [items, total] = await this.stockRepo.findAndCount({
            where,
            skip: (page - 1) * limit,
            take: limit,
            relations: ['product', 'warehouse']
        });
        const productTotalRow = await this.stockRepo.createQueryBuilder('stock')
            .select('COUNT(DISTINCT stock.product_id)', 'count')
            .where(
                Array.isArray(shopId)
                    ? 'stock.shop_id IN (:...shopIds)'
                    : 'stock.shop_id = :shopId',
                Array.isArray(shopId) ? { shopIds: shopId } : { shopId },
            )
            .andWhere(
                warehouseId === undefined
                    ? '1 = 1'
                    : 'stock.warehouse_id = :warehouseId',
                { warehouseId },
            )
            .getRawOne();
        const productTotal = Number(productTotalRow?.count || 0);
        const movementShopCondition = Array.isArray(shopId)
            ? 'movement.shop_id IN (:...shopIds)'
            : 'movement.shop_id = :shopId';
        const movementParams = Array.isArray(shopId)
            ? { shopIds: shopId }
            : { shopId };
        const latestMovementQuery = this.movementRepo.createQueryBuilder('movement')
            .select('MAX(movement.created_at)', 'latestMovementDate')
            .where(movementShopCondition, movementParams);
        if (warehouseId !== undefined) {
            latestMovementQuery.andWhere('movement.warehouse_id = :warehouseId', {
                warehouseId,
            });
        }
        const latestMovementRow = await latestMovementQuery.getRawOne();
        return {
            items,
            total,
            productTotal,
            latestMovementDate: normalizeDatabaseBusinessDate(
                latestMovementRow?.latestMovementDate,
            ),
            page,
            limit,
            totalPages: Math.ceil(total / limit),
        };
    }
    async getLowStock(shopId: number | number[], threshold?: number) {
        const isArray = Array.isArray(shopId);
        const shopCondition = isArray ? 's.shop_id = ANY($1)' : 's.shop_id = $1';
        const normalizedThreshold = threshold !== undefined && Number.isFinite(threshold)
            ? Number(threshold)
            : null;
        const rows = await AppDataSource.query(`
            SELECT
                MIN(s.id) AS id,
                s.shop_id,
                p.id AS product_id,
                p.name,
                p.sku,
                p.unit,
                p.image_url,
                COALESCE(p.min_stock, 0) AS min_stock,
                COALESCE(SUM(s.quantity), 0) AS quantity,
                COUNT(DISTINCT s.warehouse_id) AS warehouse_count
            FROM inventory_stocks s
            JOIN products p ON p.id = s.product_id
            WHERE ${shopCondition}
            GROUP BY
                s.shop_id,
                p.id,
                p.name,
                p.sku,
                p.unit,
                p.image_url,
                p.min_stock
            HAVING COALESCE(SUM(s.quantity), 0) <=
                COALESCE($2::numeric, COALESCE(p.min_stock, 0))
            ORDER BY
                COALESCE($2::numeric, COALESCE(p.min_stock, 0)) -
                    COALESCE(SUM(s.quantity), 0) DESC,
                p.name ASC,
                p.id ASC
        `, [shopId, normalizedThreshold]);

        return rows.map((row: Record<string, unknown>) => {
            const quantity = Number(row.quantity || 0);
            const minStock = Number(row.min_stock || 0);
            return {
                id: Number(row.id),
                shopId: Number(row.shop_id),
                productId: Number(row.product_id),
                quantity,
                currentQuantity: quantity,
                warehouseCount: Number(row.warehouse_count || 0),
                minStock,
                product: {
                    id: Number(row.product_id),
                    name: row.name,
                    sku: row.sku,
                    unit: row.unit,
                    imageUrl: row.image_url,
                    minStock,
                },
            };
        });
    }

    // Movements
    async getMovements(shopId: number, page = 1, limit = 20, productId?: number) {
        if (productId !== undefined) {
            const productExists = await AppDataSource.getRepository(Product).exists({
                where: { id: productId, shopId },
            });
            if (!productExists) throw new Error('Validation: Product not found for shop');
        }
        const where = productId === undefined ? { shopId } : { shopId, productId };
        const [items, total] = await this.movementRepo.findAndCount({
            where,
            skip: (page - 1) * limit,
            take: limit,
            order: { createdAt: 'DESC' },
        });
        return { items, total, page, limit, totalPages: Math.ceil(total / limit) };
    }

    // Warehouses
    async getWarehouses(shopId: number) { return this.warehouseRepo.find({ where: { shopId } }); }
    async createWarehouse(shopId: number, dto: Partial<Warehouse>) {
        const input = normalizeWarehouseInput(dto);
        return this.warehouseRepo.save(this.warehouseRepo.create({
            name: input.name,
            address: input.address ?? undefined,
            isActive: true,
            shopId,
        }));
    }

    async getCategoriesSummary(shopId: number | number[]) {
        const isArray = Array.isArray(shopId);
        const shopCondition = isArray ? 's.shop_id = ANY($1)' : 's.shop_id = $1';

        const query = `
            SELECT 
                c.id AS category_id,
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
            categoryId: r.category_id == null ? 0 : Number(r.category_id),
            name: r.name,
            skuCount: Number(r.sku_count),
            value: Number(r.value)
        }));
    }

    // Reports
    async exportXntReport(shopId: number, query: Parameters<typeof normalizeXntExportQuery>[0]) {
        if (!Number.isSafeInteger(shopId) || shopId <= 0) throw new XntExportInputError('Chọn một cửa hàng để xuất báo cáo.');
        const { from, to, warehouseId } = normalizeXntExportQuery(query);
        if (warehouseId !== undefined && !await this.warehouseRepo.findOne({ where: { id: warehouseId, shopId } })) {
            throw new XntExportInputError('Kho không thuộc cửa hàng đang xem.');
        }
        const report = await this.getXntReport(shopId, from, to, warehouseId);
        return {
            shopId, period: { from, to, dateField: 'movementBusinessDate' }, warehouseId: warehouseId ?? null,
            items: report.items, summary: summarizeXntExport(report.items)
        };
    }

    async getXntReport(shopId: number, from?: string, to?: string, warehouseId?: number) {
        const { fromDate, toDate } = resolveCurrentMonthExpensePeriod(from, to);

        return AppDataSource.transaction('REPEATABLE READ', async manager => {
            await manager.query('SET TRANSACTION READ ONLY');
            const [storage] = await manager.query(`SELECT to_regclass('public.opening_balance_batches') IS NOT NULL AS batches_ready,
                to_regclass('public.opening_balance_adjustments') IS NOT NULL AS adjustments_ready`);
            if (typeof storage?.batches_ready !== 'boolean' || typeof storage?.adjustments_ready !== 'boolean') {
                throw new Error('Không xác định được cấu trúc số dư ban đầu.');
            }
            if (storage.batches_ready !== storage.adjustments_ready) throw new Error('Cấu trúc số dư ban đầu chưa đầy đủ.');
            const openingDay = storage.batches_ready ? "WHEN 'OPENING_BALANCE' THEN ob.as_of" : '';
            const openingAtStart = storage.batches_ready
                ? "COALESCE(m.reference_type='OPENING_BALANCE' AND ob.as_of=CAST(:from AS date),false)" : 'false';
            const movementDay = `COALESCE(CASE m.reference_type WHEN 'PURCHASE_ORDER' THEN (po.order_date AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Ho_Chi_Minh')::date WHEN 'STOCK_TAKE' THEN st.stock_take_date WHEN 'SALES_ORDER' THEN (so.order_date AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Ho_Chi_Minh')::date WHEN 'SALES_RETURN' THEN (sr.return_date AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Ho_Chi_Minh')::date WHEN 'PURCHASE_WITHOUT_INVOICE' THEN pw.purchase_date WHEN 'PURCHASE_NO_INVOICE' THEN pw.purchase_date ${openingDay} END, (m.created_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Ho_Chi_Minh')::date)`;
            const beforeStart = `(${movementDay} < CAST(:from AS date) OR (${openingAtStart}))`;
            const inPeriod = `(${movementDay} >= CAST(:from AS date) AND ${movementDay} <= CAST(:to AS date) AND NOT (${openingAtStart}))`;
            const qb = manager.getRepository(Product).createQueryBuilder('p')
                .select(['p.id as id', 'p.sku as sku', 'p.name as name', 'p.unit as unit'])
                .where('p.shop_id = :shopId', { shopId })
                .leftJoin('inventory_movements', 'm', 'p.id = m.product_id AND m.shop_id = :shopId' + (warehouseId ? ' AND m.warehouse_id = :warehouseId' : ''))
                .addSelect(`COALESCE(SUM(CASE WHEN ${beforeStart} AND m.movement_type IN ('IN', 'RETURN') THEN m.quantity WHEN ${beforeStart} AND m.movement_type = 'OUT' THEN -m.quantity ELSE 0 END), 0)`, 'startQty')
                .addSelect(`COALESCE(SUM(CASE WHEN ${inPeriod} AND m.movement_type IN ('IN', 'RETURN') THEN m.quantity ELSE 0 END), 0)`, 'importQty')
                .addSelect(`COALESCE(SUM(CASE WHEN ${inPeriod} AND m.movement_type = 'OUT' THEN m.quantity ELSE 0 END), 0)`, 'exportQty')
                .addSelect(`COALESCE(SUM(CASE WHEN ${movementDay} <= CAST(:to AS date) AND m.movement_type IN ('IN', 'RETURN') THEN m.quantity WHEN ${movementDay} <= CAST(:to AS date) AND m.movement_type = 'OUT' THEN -m.quantity ELSE 0 END), 0)`, 'endQty')
                .leftJoin('purchase_orders', 'po', "m.reference_type = 'PURCHASE_ORDER' AND po.id = m.reference_id AND po.shop_id = :shopId")
                .leftJoin('stock_takes', 'st', "m.reference_type = 'STOCK_TAKE' AND st.id = m.reference_id AND st.shop_id = :shopId")
                .leftJoin('sales_orders', 'so', "m.reference_type = 'SALES_ORDER' AND so.id = m.reference_id AND so.shop_id = :shopId")
                .leftJoin('sales_returns', 'sr', "m.reference_type = 'SALES_RETURN' AND sr.id = m.reference_id AND sr.shop_id = :shopId")
                .leftJoin('purchases_without_invoice', 'pw', "m.reference_type IN ('PURCHASE_WITHOUT_INVOICE','PURCHASE_NO_INVOICE') AND pw.id = m.reference_id AND pw.shop_id = :shopId")
                .groupBy('p.id')
                .addGroupBy('p.sku')
                .addGroupBy('p.name')
                .addGroupBy('p.unit')
                .orderBy('p.id', 'ASC')
                .setParameters({ from: vietnamDateKey(fromDate), to: vietnamDateKey(toDate), warehouseId, shopId });

            if (storage.batches_ready) {
                qb.leftJoin('opening_balance_batches', 'ob', "m.reference_type='OPENING_BALANCE' AND ob.id=m.reference_id AND ob.shop_id=m.shop_id")
                    .addSelect("COUNT(*) FILTER(WHERE m.reference_type='OPENING_BALANCE' AND ob.id IS NULL)", 'missingOpeningSource');
            } else {
                qb.addSelect("COUNT(*) FILTER(WHERE m.reference_type='OPENING_BALANCE')", 'missingOpeningSource');
            }

            const rows = await qb.getRawMany();
            if (rows.some(row => Number(row.missingOpeningSource) > 0)) {
                throw new Error('Thiếu nguồn số dư ban đầu của chuyển động kho; cần đối chiếu trước khi xem báo cáo.');
            }
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
        });
    }

    async getExpiringProducts(shopId: number | number[], daysAhead: number = 30) {
        const targetDate = new Date();
        targetDate.setDate(targetDate.getDate() + daysAhead);
        const isArray = Array.isArray(shopId);

        const batches = await this.batchRepo.createQueryBuilder('b')
            .innerJoinAndSelect('b.product', 'p')
            .where(
                isArray ? 'b.shop_id IN (:...shopIds)' : 'b.shop_id = :shopId',
                isArray ? { shopIds: shopId } : { shopId },
            )
            .andWhere('b.expiry_date IS NOT NULL')
            .andWhere('b.expiry_date <= :targetDate', { targetDate })
            .andWhere('b.is_active = true')
            .andWhere('p.shop_id = b.shop_id')
            .orderBy('b.expiry_date', 'ASC')
            .getMany();
        if (!batches.length) return [];
        const quantities = await AppDataSource.query(`SELECT batch_id, SUM(remaining_qty)::int AS quantity
            FROM inventory_lots WHERE batch_id=ANY($1::int[]) AND shop_id=ANY($2::int[]) GROUP BY batch_id`,
            [batches.map(b=>b.id), isArray ? shopId : [shopId]]);
        const byBatch = new Map<number, number>(quantities.map((r: any)=>[Number(r.batch_id),Number(r.quantity)]));
        return batches.map(b=>({...b, quantity: byBatch.get(b.id) ?? b.quantity,
            quantitySource: byBatch.has(b.id) ? 'INVENTORY_LOTS' : 'LEGACY_BATCH'})).filter(b=>b.quantity>0);
    }

    async getSlowMovingProducts(shopId: number | number[], daysUnsold: number = 30) {
        // Products that have stock but haven't been in any sales movement for daysUnsold days
        const cutoffDate = new Date();
        cutoffDate.setDate(cutoffDate.getDate() - daysUnsold);
        const asOfDate = resolveVietnamBusinessDayEnd(undefined, new Date());
        const isArray = Array.isArray(shopId);
        const shopCondition = isArray
            ? 'p.shop_id IN (:...shopIds)'
            : 'p.shop_id = :shopId';
        const orderShopCondition = isArray
            ? 'sold_order.shop_id IN (:...shopIds)'
            : 'sold_order.shop_id = :shopId';
        const lastOrderShopCondition = isArray
            ? 'last_order.shop_id IN (:...shopIds)'
            : 'last_order.shop_id = :shopId';
        const shopParams = isArray ? { shopIds: shopId } : { shopId };

        const result = await AppDataSource.getRepository('products')
            .createQueryBuilder('p')
            .innerJoin(
                'inventory_stocks',
                's',
                's.product_id = p.id AND s.shop_id = p.shop_id',
            )
            .leftJoin('categories', 'c', 'c.id = p.category_id')
            .where(shopCondition, shopParams)
            .andWhere('s.quantity > 0')
            // A newly received product with no sales is not yet slow-moving.
            // Backfilled opening stock counts from its actual business date.
            .andWhere(`EXISTS (SELECT 1 FROM inventory_movements stock_started
                WHERE stock_started.shop_id=p.shop_id AND stock_started.product_id=p.id
                  AND stock_started.movement_type IN ('IN','RETURN') AND stock_started.quantity>0
                  AND (CASE WHEN stock_started.reference_type='OPENING_BALANCE'
                    THEN (SELECT opening.as_of::timestamp FROM opening_balance_batches opening
                      WHERE opening.id=stock_started.reference_id AND opening.shop_id=stock_started.shop_id)
                    ELSE stock_started.created_at END)<=:cutoff)`, {cutoff:cutoffDate})
            .andWhere((qb) => {
                const subQuery = qb.subQuery()
                    .select('sold_item.product_id')
                    .from('sales_order_items', 'sold_item')
                    .innerJoin(
                        'sales_orders',
                        'sold_order',
                        'sold_order.id = sold_item.order_id',
                    )
                    .where(orderShopCondition)
                    .andWhere('sold_order.shop_id = p.shop_id')
                    .andWhere("sold_order.status != 'CANCELLED'")
                    .andWhere('sold_order.order_date >= :cutoff', { cutoff: cutoffDate })
                    .andWhere('sold_order.order_date <= :asOf', { asOf: asOfDate })
                    .getQuery();
                return 'p.id NOT IN ' + subQuery;
            })
            .select([
                'p.id as id',
                'p.sku as sku',
                'p.name as name',
                'p.unit as unit',
                'p.shop_id as "shopId"',
                'p.cost_price as "costPrice"',
                "COALESCE(c.name, 'Chưa phân loại') as category",
            ])
            .addSelect('SUM(s.quantity)', 'currentStock')
            .addSelect('SUM(s.quantity) * p.cost_price', 'stockValue')
            .addSelect(`(
                SELECT MAX(last_order.order_date)
                FROM sales_order_items last_item
                JOIN sales_orders last_order ON last_order.id = last_item.order_id
                WHERE last_item.product_id = p.id
                  AND ${lastOrderShopCondition}
                  AND last_order.shop_id = p.shop_id
                  AND last_order.status != 'CANCELLED'
                  AND last_order.order_date <= :asOf
            )`, 'lastSoldAt')
            .setParameter('asOf', asOfDate)
            .groupBy('p.id')
            .addGroupBy('p.sku')
            .addGroupBy('p.name')
            .addGroupBy('p.unit')
            .addGroupBy('p.shop_id')
            .addGroupBy('p.cost_price')
            .addGroupBy('c.name')
            .orderBy('"stockValue"', 'DESC')
            .addOrderBy('p.id', 'ASC')
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
                shopId: Number(row.shopId),
                category: row.category,
                costPrice: Number(row.costPrice || 0),
                currentStock: Number(row.currentStock || 0),
                currentQuantity: Number(row.currentStock || 0),
                stockValue: Number(row.stockValue || 0),
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
                p.image_url,
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
            imageUrl: row.image_url || null,
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
    async getPurchaseOrders(shopId: number, page = 1, limit = 20, search = '', status = '') {
        const balanceAsOf = vietnamDateKey(new Date());
        return AppDataSource.transaction('REPEATABLE READ', async manager => {
            await manager.query('SET TRANSACTION READ ONLY');
            const query = normalizePurchaseOrderQuery({ page, limit, search, status });
            const qb = manager.getRepository(PurchaseOrder).createQueryBuilder('po')
                .leftJoin('po.supplier', 'supplier', 'supplier.shopId = po.shopId')
                .where('po.shopId = :shopId', { shopId })
                .orderBy('po.orderDate', 'DESC').addOrderBy('po.id', 'DESC');
            if (query.status) qb.andWhere('po.status = :status', { status: query.status });
            if (query.search) {
                qb.andWhere(new Brackets(where => {
                    where.where(vietnameseSearchExpression('po.orderCode'));
                    for (const field of ['po.invoiceNumber', 'po.notes', 'supplier.name', 'supplier.code']) {
                        where.orWhere(vietnameseSearchExpression(field));
                    }
                    // Resolve matching order IDs once for this shop. A correlated
                    // product scan here repeats the same text search for every order.
                    // Keep this separate from returned items so all lines remain visible.
                    where.orWhere(`po.id IN (SELECT search_item.order_id FROM purchase_order_items search_item
                    JOIN products search_product ON search_product.id = search_item.product_id
                        AND search_product.shop_id = :shopId
                    WHERE (
                        ${vietnameseSearchExpression('search_product.name')} OR
                        ${vietnameseSearchExpression('search_product.sku')} OR
                        ${vietnameseSearchExpression('search_product.barcode')}
                    ))`);
                }), vietnameseSearchParams(query.search));
            }
            // Paginate parent orders before joining their items. This avoids the
            // ORM's separate ID-fetch round trip without cutting off order lines.
            const pageIds = qb.clone().select('po.id')
                .offset((query.page - 1) * query.limit).limit(query.limit);
            const details = manager.getRepository(PurchaseOrder).createQueryBuilder('po')
                .leftJoinAndSelect('po.items', 'item')
                .leftJoinAndSelect('item.product', 'product', 'product.shopId = po.shopId')
                .leftJoinAndSelect('po.supplier', 'supplier', 'supplier.shopId = po.shopId')
                .where('po.shopId = :shopId', { shopId })
                .andWhere(`po.id IN (${pageIds.getQuery()})`)
                .setParameters(pageIds.getParameters())
                .orderBy('po.orderDate', 'DESC').addOrderBy('po.id', 'DESC');
            const [items, total] = await Promise.all([details.getMany(), qb.getCount()]);
            return { items: await withOrderDebtBalances(manager, 'PURCHASE', items, balanceAsOf), total, page: query.page, limit: query.limit, totalPages: Math.ceil(total / query.limit) };
        });
    }
    async getPurchaseOrder(shopId: number, id: number) {
        const balanceAsOf = vietnamDateKey(new Date());
        return AppDataSource.transaction('REPEATABLE READ', async manager => {
            await manager.query('SET TRANSACTION READ ONLY');
            const order = await manager.getRepository(PurchaseOrder).createQueryBuilder('po')
                .leftJoinAndSelect('po.items', 'item')
                .leftJoinAndSelect('item.product', 'product', 'product.shopId = po.shopId')
                .leftJoinAndSelect('po.supplier', 'supplier', 'supplier.shopId = po.shopId')
                .where('po.shopId = :shopId AND po.id = :id', { shopId, id }).getOne();
            return order ? (await withOrderDebtBalances(manager, 'PURCHASE', [order], balanceAsOf))[0] : null;
        });
    }

    async createPurchaseOrderForActor(shopId: number, dto: unknown, actor: PurchaseWriteActor) {
        return this.createPurchaseOrder(shopId, dto, undefined, actor);
    }
    async updatePurchaseOrderForActor(shopId: number, id: number, dto: unknown, actor: PurchaseWriteActor) {
        return this.updatePurchaseOrder(shopId, id, dto, actor);
    }
    async deletePurchaseOrderForActor(shopId: number, id: number, actor: PurchaseWriteActor) {
        return this.deletePurchaseOrder(shopId, id, actor);
    }

    async createPurchaseOrder(shopId: number, dto: any, externalRunner?: QueryRunner, actor?: PurchaseWriteActor) {
        const input = normalizePurchaseOrderCreateInput(dto);
        const queryRunner = externalRunner ?? AppDataSource.createQueryRunner();
        if (!externalRunner) {
            await queryRunner.connect();
            await queryRunner.startTransaction();
        }

        try {
            const manager = queryRunner.manager;
            if (actor) await manager.query("SET LOCAL lock_timeout = '5000ms'");
            await lockShopMutation(manager, shopId);
            if (actor) {
                const member = await requirePurchaseWriteAuthority(manager, shopId, actor);
                await requireOpenPurchaseDay(manager, shopId, input.orderDate, member.memberType);
            }

            const targetWarehouseId = input.warehouseId
                ? Number(input.warehouseId)
                : await this.ensureDefaultWarehouseId(shopId, manager);
            await this.assertWarehouseBelongsToShop(shopId, targetWarehouseId, manager);

            const supplier = await manager.findOne(Supplier, {
                where: { id: input.supplierId, shopId, isActive: true },
            });
            if (!supplier) throw new Error('Validation: Nhà cung cấp không thuộc cửa hàng');
            const productIds = input.items.map((item) => item.productId);
            const productCount = await manager.createQueryBuilder(Product, 'p')
                .where('p.shopId = :shopId AND p.isActive = true', { shopId })
                .andWhere('p.id IN (:...productIds)', { productIds })
                .getCount();
            if (productCount !== productIds.length) throw new Error('Validation: Có sản phẩm không thuộc cửa hàng');

            let totalCents = 0n;
            const items = input.items.map((i) => {
                const cents = BigInt(i.quantity) * openingEffectCents(i.unitPrice);
                totalCents += cents;
                const sub = openingEffectValue(cents);
                return manager.create(PurchaseOrderItem, {
                    productId: i.productId,
                    quantity: i.quantity,
                    unitPrice: i.unitPrice,
                    subtotal: sub,
                });
            });

            const totalAmount = openingEffectValue(totalCents);
            const po = manager.create(PurchaseOrder, {
                supplierId: input.supplierId,
                warehouseId: targetWarehouseId,
                orderDate: input.orderDate,
                paymentDueDate: input.paymentDueDate ? new Date(`${input.paymentDueDate}T00:00:00Z`) : undefined,
                invoiceNumber: input.invoiceNumber ?? undefined,
                notes: input.notes ?? undefined,
                orderCode: 'PO' + randomBytes(9).toString('hex'),
                subtotal: totalAmount,
                discountAmount: 0,
                taxAmount: 0,
                totalAmount,
                paidAmount: 0,
                items,
                shopId,
                status: 'PENDING',
                createdBy: actor?.id,
            });
            const savedPO = await manager.save(PurchaseOrder, po);

            if (!externalRunner) await queryRunner.commitTransaction();
            return savedPO;
        } catch (error) {
            if (!externalRunner) await queryRunner.rollbackTransaction();
            throw error;
        } finally {
            if (!externalRunner) await queryRunner.release();
        }
    }

    async updatePurchaseOrder(shopId: number, id: number, dto: any, actor?: PurchaseWriteActor) {
        const input = normalizePurchaseOrderUpdateInput(dto);
        const queryRunner = AppDataSource.createQueryRunner();
        await queryRunner.connect();
        await queryRunner.startTransaction();

        try {
            const manager = queryRunner.manager;
            if (actor) await manager.query("SET LOCAL lock_timeout = '5000ms'");
            await lockShopMutation(manager, shopId);
            const member = actor ? await requirePurchaseWriteAuthority(manager, shopId, actor) : undefined;
            const po = await manager.findOne(PurchaseOrder, {
                where: { id, shopId },
                relations: ['items']
            });
            if (!po) throw new PurchaseWriteError('Không tìm thấy đơn nhập trong cửa hàng này', 404);
            if (member) await requireOpenPurchaseDay(manager, shopId, new Date(po.orderDate), member.memberType);

            const currentStatus = String(po.status || 'PENDING').toUpperCase();
            const nextStatus = input.status;
            if (currentStatus !== 'PENDING') {
                const isIdempotentStatusUpdate =
                    input.warehouseId === undefined &&
                    nextStatus === currentStatus;
                if (isIdempotentStatusUpdate) {
                    await queryRunner.commitTransaction();
                    return po;
                }
                throw new Error('Validation: Completed or cancelled purchase order is immutable');
            }
            await this.assertPendingPurchaseUnposted(manager, po);

            if (input.warehouseId) {
                await this.assertWarehouseBelongsToShop(shopId, input.warehouseId, manager);
                po.warehouseId = input.warehouseId;
            }

            // If changing status from PENDING to COMPLETED, increase stock and post journal
            if (nextStatus === 'COMPLETED') {
                const sourceInvoice = await manager.findOne(Invoice, { where: { shopId, referenceType: 'PURCHASE_ORDER', referenceId: po.id } });
                if (sourceInvoice && Math.abs(Number(sourceInvoice.totalAmount) - Number(po.totalAmount)) > 1) {
                    throw new PurchaseWriteError('Tổng phiếu nhập chưa khớp hóa đơn liên kết. Đối chiếu lại trước khi ghi kho.', 409);
                }
                try {
                    const checked = normalizePurchaseOrderCreateInput({
                        supplierId: po.supplierId, warehouseId: po.warehouseId,
                        orderDate: new Date(po.orderDate).toISOString(),
                        items: po.items.map(i => ({ productId: i.productId, quantity: i.quantity, unitPrice: i.unitPrice })),
                    });
                    const subtotal = checked.items.reduce((sum, i) => sum + BigInt(i.quantity) * openingEffectCents(i.unitPrice), 0n);
                    if (subtotal !== openingEffectCents(po.subtotal) || openingEffectCents(po.discountAmount) < 0n
                        || openingEffectCents(po.taxAmount) < 0n || openingEffectCents(po.discountAmount) > subtotal
                        || openingEffectCents(po.totalAmount) !== subtotal - openingEffectCents(po.discountAmount) + openingEffectCents(po.taxAmount)
                        || openingEffectCents(po.paidAmount) !== 0n) throw new Error();
                } catch {
                    throw new PurchaseWriteError('Cần đối chiếu dòng hàng, tổng tiền và khoản đã trả của đơn nhập trước khi hoàn tất', 409);
                }
                await this.assertWarehouseBelongsToShop(shopId, po.warehouseId, manager);
                const supplier = await manager.findOne(Supplier, { where: { id: po.supplierId, shopId, isActive: true } });
                if (!supplier) throw new PurchaseWriteError('Cần đối chiếu nhà cung cấp của đơn nhập trước khi hoàn tất', 409);
                const productIds = po.items.map(i => i.productId);
                const products = await manager.count(Product, { where: { id: In(productIds), shopId, isActive: true } });
                if (products !== productIds.length) throw new PurchaseWriteError('Cần đối chiếu sản phẩm của đơn nhập trước khi hoàn tất', 409);
                for (const item of (po.items || [])) {
                    if (item.productId && item.quantity > 0 && item.unitPrice > 0) {
                        await this.cogsService.addInventoryLot({
                            productId: Number(item.productId),
                            quantity: Number(item.quantity),
                            costPrice: Number(item.unitPrice),
                            purchaseId: po.id,
                            notes: `PO ${po.orderCode}`,
                            shopId,
                            lotDate: new Date(po.orderDate),
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
                        manager,
                        new Date(po.orderDate),
                    );
                    const paidAmount = Number(po.paidAmount || 0);
                    if (Number(po.totalAmount) > paidAmount) {
                        const supplier = await manager.findOneByOrFail(Supplier, { id: po.supplierId, shopId });
                        const dueDate = po.paymentDueDate
                            ? new Date(po.paymentDueDate)
                            : new Date(po.orderDate);
                        if (!po.paymentDueDate) dueDate.setUTCDate(dueDate.getUTCDate() + Number(supplier.paymentTermDays || 0));
                        await manager.save(Payable, manager.create(Payable, {
                            shopId, supplierId: po.supplierId, purchaseOrderId: po.id,
                            amount: Number(po.totalAmount), paidAmount, dueDate,
                            status: paidAmount > 0 ? 'PARTIAL' : 'UNPAID',
                            notes: `Công nợ từ đơn nhập ${po.orderCode}`,
                        }));
                    }
                }
            }

            po.status = nextStatus;
            const saved = await manager.save(PurchaseOrder, po);
            if (nextStatus === 'COMPLETED') {
                const supplier = await manager.findOneByOrFail(Supplier, { id: po.supplierId, shopId });
                const balance = await new SupplierService().balanceInTransaction(manager, supplier, vietnamDateKey(new Date()));
                await manager.update(Supplier, { id: supplier.id, shopId }, { balance });
            }

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

    private async assertPendingPurchaseUnposted(manager: EntityManager, po: PurchaseOrder) {
        const [proof] = await manager.query(`SELECT
            EXISTS(SELECT 1 FROM payables WHERE purchase_order_id=$1) OR
            EXISTS(SELECT 1 FROM inventory_lots WHERE purchase_id=$1) OR
            EXISTS(SELECT 1 FROM inventory_movements WHERE reference_type='PURCHASE_ORDER' AND reference_id=$1) OR
            EXISTS(SELECT 1 FROM journal_entries WHERE reference_type='PURCHASE_ORDER' AND reference_id=$1 AND NOT is_voided) OR
            EXISTS(SELECT 1 FROM cash_transactions WHERE reference_type='PURCHASE_ORDER' AND reference_id=$1) AS posted`, [po.id]);
        if (proof.posted || openingEffectCents(po.paidAmount) !== 0n) throw new PurchaseWriteError('Cần đối chiếu chứng từ tiền, kho và công nợ đã liên kết với đơn nhập đang chờ trước khi thay đổi', 409);
    }

    async deletePurchaseOrder(shopId: number, id: number, actor?: PurchaseWriteActor) {
        return AppDataSource.transaction(async manager => {
            if (actor) await manager.query("SET LOCAL lock_timeout = '5000ms'");
            await lockShopMutation(manager, shopId);
            const member = actor ? await requirePurchaseWriteAuthority(manager, shopId, actor) : undefined;
            const po = await manager.findOne(PurchaseOrder, { where: { id, shopId } });
            if (!po) return { success: true };
            if (member) await requireOpenPurchaseDay(manager, shopId, new Date(po.orderDate), member.memberType);
            if (String(po.status || 'PENDING').toUpperCase() !== 'PENDING') throw new PurchaseWriteError('Chỉ được xóa đơn nhập đang chờ xử lý', 409);
            await this.assertPendingPurchaseUnposted(manager, po);
            await manager.delete(PurchaseOrderItem, { order: { id: po.id } });
            await manager.delete(PurchaseOrder, { id: po.id, shopId });
            return { success: true };
        });
    }

    // Stock Takes
    async getStockTakes(shopId: number, page = 1, limit = 20) {
        const [items, total] = await this.stockTakeRepo.findAndCount({ where: { shopId }, skip: (page - 1) * limit, take: limit, order: { id: 'DESC' }, relations: ['items', 'items.product'] });
        return { items, total, page, limit, totalPages: Math.ceil(total / limit) };
    }
    async createStockTake(shopId: number, dto: any) {
        const input = normalizeStockTakeCreateInput(dto);
        const warehouseId = input.warehouseId || await this.ensureDefaultWarehouseId(shopId);
        await this.assertWarehouseBelongsToShop(shopId, warehouseId);
        const productIds = input.items.map((item) => item.productId);
        const products = await AppDataSource.getRepository(Product).createQueryBuilder('p')
            .where('p.shopId = :shopId AND p.isActive = true', { shopId })
            .andWhere('p.id IN (:...productIds)', { productIds })
            .getMany();
        if (products.length !== productIds.length) throw new Error('Validation: Có sản phẩm không thuộc cửa hàng');
        const stocks = await this.stockRepo.find({ where: productIds.map((productId) => ({ shopId, warehouseId, productId })) });
        const stockByProduct = new Map(stocks.map((stock) => [Number(stock.productId), Number(stock.quantity || 0)]));
        const items = input.items.map((item) => {
            const systemQty = stockByProduct.get(item.productId) ?? 0;
            return this.stockTakeItemRepo.create({
                product: { id: item.productId },
                systemQty,
                actualQty: item.actualQty,
                difference: item.actualQty - systemQty,
                notes: item.notes ?? undefined,
            });
        });
        return this.stockTakeRepo.save(this.stockTakeRepo.create({
            stockTakeCode: 'ST' + Date.now().toString().slice(-8),
            stockTakeDate: new Date(`${input.stockTakeDate}T00:00:00Z`),
            status: 'DRAFT',
            notes: input.notes ?? undefined,
            warehouseId,
            items,
            shopId,
        }));
    }

    async updateStockTake(shopId: number, id: number, dto: any) {
        const input = normalizeStockTakeStatusInput(dto);
        const queryRunner = AppDataSource.createQueryRunner();
        await queryRunner.connect();
        await queryRunner.startTransaction();

        try {
            const manager = queryRunner.manager;
            await lockShopMutation(manager, shopId);
            const stockTake = await manager.findOne(StockTake, { where: { id, shopId }, relations: ['items', 'items.product'] });
            if (!stockTake) throw new Error('StockTake not found');

            const currentStatus = String(stockTake.status || 'DRAFT').toUpperCase();
            if (currentStatus !== 'DRAFT') {
                if (input.status === currentStatus) {
                    await queryRunner.commitTransaction();
                    return stockTake;
                }
                throw new Error('Validation: Phiếu kiểm kê đã kết thúc và không thể thay đổi');
            }
            if (input.status === 'COMPLETED') {
                for (const item of (stockTake.items || [])) {
                    const warehouseId = stockTake.warehouseId || await this.ensureDefaultWarehouseId(shopId, manager);
                    const productId = item.product?.id || (item as any).productId;
                    let stock = await manager.findOne(InventoryStock, { where: { shopId, productId, warehouseId } as any });
                    if (!stock) stock = manager.create(InventoryStock, { shopId, productId, warehouseId, quantity: 0, updatedAt: new Date() });
                    item.systemQty = Number(stock.quantity || 0);
                    item.difference = Number(item.actualQty) - item.systemQty;
                    if (item.difference !== 0) {
                        await this.cogsService.adjustForStockTake(shopId, Number(productId), Number(item.difference), new Date(stockTake.stockTakeDate), manager);
                        stock.quantity = Number(item.actualQty);
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
                    await manager.save(StockTakeItem, item);
                }
                stockTake.completedAt = new Date();
            }

            stockTake.status = input.status;
            if (input.notes !== null) stockTake.notes = input.notes;
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
        if (stockTake && String(stockTake.status).toUpperCase() !== 'DRAFT') {
            throw new Error('Validation: Chỉ được xóa phiếu kiểm kê nháp');
        }
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
