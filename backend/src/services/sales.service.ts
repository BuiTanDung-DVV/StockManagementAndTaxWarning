import { AppDataSource } from '../config/db.config';
import {
    buildVietnamPeriodKeys,
    resolveCurrentMonthExpensePeriod,
    vietnamDateKey,
} from '../finance/finance-period.utils';
import { normalizeDatabaseBusinessDate } from '../system/data-freshness.utils';
import { SalesOrder, SalesOrderItem, SalesReturn, SalesReturnItem, SalesOrderPayment, SalesOrderLotDeduction } from '../sales/entities';
import {
    Customer,
    DebtPaymentHistory,
    Receivable,
} from '../customer/entities';
import { applyDebtPayment } from '../customer/debt.utils';
import { Product } from '../product/entities';
import { COGSService } from './cogs.service';
import { FinanceService } from './finance.service';
import { PostingService } from './posting.service';
import { JournalEntry } from '../finance/ledger.entity';
import { InventoryMovement, InventoryStock } from '../inventory/entities';
import { InventoryLot } from '../inventory/lot.entity';
import { EntityManager } from 'typeorm';
import {
    calculateGrossMarginPercentage,
    calculateRevenueGrowth,
    normalizeSalesStatusFilter,
} from '../sales/sales-metric.utils';
import { assertAllowedUnitPrice } from '../sales/sales-pricing.utils';
import {
    buildAllocatedMerchandiseRevenueSql,
    calculateSalesAccountingSplit,
    calculateSalesTaxLines,
} from '../sales/sales-accounting.utils';
import {
    groupSettledPaymentsByMethod,
    normalizeSettledPaymentMethod,
    paymentLedgerAccountCode,
} from '../sales/payment-ledger.utils';

export class SalesService {
    private orderRepo = AppDataSource.getRepository(SalesOrder);
    private orderItemRepo = AppDataSource.getRepository(SalesOrderItem);
    private returnRepo = AppDataSource.getRepository(SalesReturn);
    private paymentRepo = AppDataSource.getRepository(SalesOrderPayment);
    private customerRepo = AppDataSource.getRepository(Customer);
    private receivableRepo = AppDataSource.getRepository(Receivable);
    private productRepo = AppDataSource.getRepository(Product);
    private stockRepo = AppDataSource.getRepository(InventoryStock);
    private movementRepo = AppDataSource.getRepository(InventoryMovement);
    private cogsService = new COGSService();
    private financeService = new FinanceService();
    private postingService = new PostingService();

    async findAll(
        shopId: number | number[],
        page = 1,
        limit = 20,
        customerId?: number,
        status?: string,
        search?: string,
        from?: string,
        to?: string,
    ) {
        const safePage = Math.max(Number(page) || 1, 1);
        const safeLimit = Math.min(Math.max(Number(limit) || 20, 1), 100);
        const statuses = normalizeSalesStatusFilter(status);
        const qb = this.orderRepo.createQueryBuilder('o')
            .leftJoinAndSelect('o.customer', 'customer');

        if (Array.isArray(shopId)) {
            if (shopId.length === 0) {
                throw new Error('Validation: Phạm vi cửa hàng không hợp lệ');
            }
            qb.where('o.shopId IN (:...shopIds)', { shopIds: shopId });
        } else {
            qb.where('o.shopId = :shopId', { shopId });
        }

        if (customerId) qb.andWhere('customer.id = :customerId', { customerId });
        if (statuses) qb.andWhere('o.status IN (:...statuses)', { statuses });
        if ((from && !to) || (!from && to)) {
            throw new Error('Validation: Kỳ danh sách cần đủ ngày bắt đầu và kết thúc');
        }
        if (from && to) {
            const { fromDate, toDate } = resolveCurrentMonthExpensePeriod(from, to);
            qb.andWhere(
                "o.orderDate >= CAST(:fromKey AS date) AND o.orderDate < CAST(:toKey AS date) + INTERVAL '1 day'",
                {
                    fromKey: vietnamDateKey(fromDate),
                    toKey: vietnamDateKey(toDate),
                },
            );
        }
        if (search?.trim()) {
            qb.andWhere(
                '(LOWER(o.orderCode) LIKE :search OR LOWER(COALESCE(customer.name, \'\')) LIKE :search OR LOWER(COALESCE(customer.phone, \'\')) LIKE :search)',
                { search: `%${search.trim().toLowerCase()}%` },
            );
        }

        const [items, total] = await qb
            .orderBy('o.orderDate', 'DESC')
            .addOrderBy('o.id', 'DESC')
            .skip((safePage - 1) * safeLimit)
            .take(safeLimit)
            .getManyAndCount();
        return { items, total, page: safePage, limit: safeLimit, totalPages: Math.ceil(total / safeLimit) };
    }
    
    async summary(shopId: number | number[], from?: string, to?: string) {
        const { fromDate, toDate } = resolveCurrentMonthExpensePeriod(from, to);
        const fromKey = vietnamDateKey(fromDate);
        const toKey = vietnamDateKey(toDate);

        const shopCondition = Array.isArray(shopId) ? 'o.shop_id IN (:...shopIds)' : 'o.shop_id = :shopId';
        const shopParams = Array.isArray(shopId) ? { shopIds: shopId } : { shopId };
        const result = await this.orderRepo.createQueryBuilder('o')
            .select('COALESCE(SUM(o.subtotal - o.discount_amount), 0)', 'grossNetSalesRevenue')
            .addSelect('COALESCE(SUM(o.tax_amount), 0)', 'outputTax')
            .addSelect('COALESCE(SUM(o.total_amount), 0)', 'grossChargedAmount')
            .addSelect('COALESCE(SUM(o.total_cogs), 0)', 'totalCogs')
            .addSelect('COUNT(o.id)', 'orderCount')
            .where(`${shopCondition} AND o.order_date >= CAST(:fromKey AS date) AND o.order_date < CAST(:toKey AS date) + INTERVAL '1 day' AND o.status != 'CANCELLED'`, { ...shopParams, fromKey, toKey })
            .getRawOne();
        const latestOrderRow = await this.orderRepo.createQueryBuilder('o')
            .select('MAX(o.order_date)', 'latestOrderDate')
            .where(
                `${shopCondition} AND o.order_date < CAST(:toKey AS date) + INTERVAL '1 day' AND o.status != 'CANCELLED'`,
                { ...shopParams, toKey },
            )
            .getRawOne();

        const rawReturnShopCondition = Array.isArray(shopId)
            ? 'r.shop_id = ANY($1)'
            : 'r.shop_id = $1';
        const returnedLineRevenueSql = buildAllocatedMerchandiseRevenueSql(
            'ri.subtotal',
            'returned_order',
        );
        const [returnResult] = await AppDataSource.query(`
            WITH return_totals AS (
                SELECT
                    r.id,
                    SUM(${returnedLineRevenueSql}) AS net_sales,
                    SUM(
                        CASE
                            WHEN COALESCE(sold_item.quantity, 0) <= 0 THEN 0
                            ELSE sold_item.tax_amount * ri.quantity / sold_item.quantity
                        END
                    ) AS tax_amount
                FROM sales_returns r
                JOIN sales_orders returned_order ON returned_order.id = r.order_id
                JOIN sales_return_items ri ON ri.return_id = r.id
                JOIN sales_order_items sold_item
                  ON sold_item.order_id = returned_order.id
                 AND sold_item.product_id = ri.product_id
                WHERE ${rawReturnShopCondition}
                  AND r.return_date >= $2::date
                  AND r.return_date < ($3::date + interval '1 day')
                  AND UPPER(COALESCE(r.status, '')) NOT IN ('CANCELLED', 'REJECTED')
                GROUP BY r.id
            )
            SELECT
                COALESCE(SUM(net_sales), 0) AS "returnNetSalesRevenue",
                COALESCE(SUM(tax_amount), 0) AS "returnTax",
                COALESCE(SUM(net_sales + tax_amount), 0) AS "returnChargedAmount",
                COALESCE((
                    SELECT SUM(r.refund_amount)
                    FROM sales_returns r
                    WHERE ${rawReturnShopCondition}
                      AND r.return_date >= $2::date
                      AND r.return_date < ($3::date + interval '1 day')
                      AND UPPER(COALESCE(r.status, '')) NOT IN ('CANCELLED', 'REJECTED')
                ), 0) AS "refundAmount"
            FROM return_totals
        `, [shopId, fromKey, toKey]);
        const returnCogsShopCondition = Array.isArray(shopId)
            ? 'r.shop_id = ANY($1)'
            : 'r.shop_id = $1';
        const [returnedCogsResult] = await AppDataSource.query(`
            SELECT COALESCE(SUM(ri.quantity * sold.unit_cost), 0) AS "returnedCogs"
            FROM sales_returns r
            JOIN sales_return_items ri ON ri.return_id = r.id
            JOIN (
                SELECT
                    order_id,
                    product_id,
                    COALESCE(
                        SUM(quantity * cost_price) / NULLIF(SUM(quantity), 0),
                        0
                    ) AS unit_cost
                FROM sales_order_items
                GROUP BY order_id, product_id
            ) sold
              ON sold.order_id = r.order_id
             AND sold.product_id = ri.product_id
            WHERE ${returnCogsShopCondition}
              AND r.return_date >= $2::date
              AND r.return_date < ($3::date + interval '1 day')
              AND UPPER(COALESCE(r.status, '')) NOT IN ('CANCELLED', 'REJECTED')
        `, [shopId, fromKey, toKey]);

        const diffDays = Math.ceil((toDate.getTime() - fromDate.getTime()) / (1000 * 3600 * 24));
        const dateFormat = diffDays > 60 ? 'YYYY-MM' : 'YYYY-MM-DD';

        const orderDateBucket = `TO_CHAR(o.order_date, '${dateFormat}')`;
        const returnDateBucket = `TO_CHAR(r.return_date, '${dateFormat}')`;
        const daily = await this.orderRepo.createQueryBuilder('o')
            .select(orderDateBucket, 'date')
            .addSelect('COALESCE(SUM(o.subtotal - o.discount_amount), 0)', 'revenue')
            .addSelect('COALESCE(SUM(o.total_cogs), 0)', 'cogs')
            .addSelect('COUNT(o.id)', 'orderCount')
            .where(`${shopCondition} AND o.order_date >= CAST(:fromKey AS date) AND o.order_date < CAST(:toKey AS date) + INTERVAL '1 day' AND o.status != 'CANCELLED'`, { ...shopParams, fromKey, toKey })
            .groupBy(orderDateBucket)
            .orderBy(orderDateBucket, 'ASC')
            .getRawMany();
        const dailyReturns: Array<{ date: string; returnValue: string | number }> = await AppDataSource.query(`
            SELECT
                ${returnDateBucket} AS date,
                COALESCE(SUM(${returnedLineRevenueSql}), 0) AS "returnValue"
            FROM sales_returns r
            JOIN sales_orders returned_order ON returned_order.id = r.order_id
            JOIN sales_return_items ri ON ri.return_id = r.id
            WHERE ${rawReturnShopCondition}
              AND r.return_date >= $2::date
              AND r.return_date < ($3::date + interval '1 day')
              AND UPPER(COALESCE(r.status, '')) NOT IN ('CANCELLED', 'REJECTED')
            GROUP BY ${returnDateBucket}
        `, [shopId, fromKey, toKey]);
        const dailyReturnMap = new Map<string, number>(
            dailyReturns.map((row) => [row.date, Number(row.returnValue || 0)]),
        );
        const dailyReturnedCogs: Array<{ date: string; returnedCogs: string | number }> = await AppDataSource.query(`
            SELECT
                ${returnDateBucket} AS date,
                COALESCE(SUM(ri.quantity * sold.unit_cost), 0) AS "returnedCogs"
            FROM sales_returns r
            JOIN sales_return_items ri ON ri.return_id = r.id
            JOIN (
                SELECT
                    order_id,
                    product_id,
                    COALESCE(
                        SUM(quantity * cost_price) / NULLIF(SUM(quantity), 0),
                        0
                    ) AS unit_cost
                FROM sales_order_items
                GROUP BY order_id, product_id
            ) sold
              ON sold.order_id = r.order_id
             AND sold.product_id = ri.product_id
            WHERE ${returnCogsShopCondition}
              AND r.return_date >= $2::date
              AND r.return_date < ($3::date + interval '1 day')
              AND UPPER(COALESCE(r.status, '')) NOT IN ('CANCELLED', 'REJECTED')
            GROUP BY ${returnDateBucket}
        `, [shopId, fromKey, toKey]);
        const dailyReturnedCogsMap = new Map<string, number>(
            dailyReturnedCogs.map((row) => [row.date, Number(row.returnedCogs || 0)]),
        );

        const dailyMap = new Map();
        daily.forEach(d => {
            dailyMap.set(d.date, {
                revenue: Number(d.revenue || 0) - (dailyReturnMap.get(d.date) || 0),
                cogs: Number(d.cogs || 0) - (dailyReturnedCogsMap.get(d.date) || 0),
                orderCount: Number(d.orderCount || 0)
            });
        });
        dailyReturns.forEach((row) => {
            if (!dailyMap.has(row.date)) {
                dailyMap.set(row.date, {
                    revenue: -Number(row.returnValue || 0),
                    cogs: -(dailyReturnedCogsMap.get(row.date) || 0),
                    orderCount: 0,
                });
            }
        });

        const filledDaily = buildVietnamPeriodKeys(
            fromDate,
            toDate,
            dateFormat === 'YYYY-MM-DD' ? 'day' : 'month',
        ).map((date) => {
            const revenue = Number(dailyMap.get(date)?.revenue || 0);
            const cogs = Number(dailyMap.get(date)?.cogs || 0);
            const grossProfit = revenue - cogs;
            return {
                date,
                revenue,
                cogs,
                grossProfit,
                marginPct: revenue > 0
                    ? Number(((grossProfit / revenue) * 100).toFixed(2))
                    : 0,
                orderCount: Number(dailyMap.get(date)?.orderCount || 0),
            };
        });

        const grossNetSalesRevenue = Number(result?.grossNetSalesRevenue || 0);
        const returnNetSalesRevenue = Number(returnResult?.returnNetSalesRevenue || 0);
        const outputTax = Number(result?.outputTax || 0) - Number(returnResult?.returnTax || 0);
        const grossChargedAmount = Number(result?.grossChargedAmount || 0);
        const returnChargedAmount = Number(returnResult?.returnChargedAmount || 0);
        const refundAmount = Number(returnResult?.refundAmount || 0);
        const grossCogs = Number(result?.totalCogs || 0);
        const returnedCogs = Number(returnedCogsResult?.returnedCogs || 0);
        const netSalesRevenue = grossNetSalesRevenue - returnNetSalesRevenue;
        const returnRatePct = grossNetSalesRevenue > 0
            ? Number(((returnNetSalesRevenue / grossNetSalesRevenue) * 100).toFixed(2))
            : 0;
        // Keep totalRevenue as the historical gross charged amount for tax-alert
        // compatibility. Accounting KPIs must use netSalesRevenue (excluding VAT).
        const totalRevenue = grossChargedAmount - returnChargedAmount;
        const totalCogs = Math.max(grossCogs - returnedCogs, 0);
        return {
            grossRevenue: grossChargedAmount,
            refundAmount,
            returnValue: returnChargedAmount,
            totalRevenue,
            grossNetSalesRevenue,
            returnNetSalesRevenue,
            returnRatePct,
            netSalesRevenue,
            outputTax,
            netChargedAmount: grossChargedAmount - refundAmount,
            grossCogs,
            returnedCogs,
            totalCogs,
            grossProfit: netSalesRevenue - totalCogs,
            orderCount: Number(result?.orderCount || 0),
            latestOrderDate: normalizeDatabaseBusinessDate(
                latestOrderRow?.latestOrderDate,
            ),
            daily: filledDaily,
            period: {
                from: fromKey,
                to: toKey,
            },
            timezone: 'Asia/Ho_Chi_Minh',
            scope: Array.isArray(shopId) ? 'ALL_SHOPS' : 'SHOP',
        };
    }

    async getTopProducts(
        shopId: number | number[],
        from?: string,
        to?: string,
        previousFrom?: string,
        previousTo?: string,
    ) {
        const { fromDate, toDate } = resolveCurrentMonthExpensePeriod(from, to);
        const fromKey = vietnamDateKey(fromDate);
        const toKey = vietnamDateKey(toDate);

        const isArray = Array.isArray(shopId);
        const shopCondition = isArray ? 'o.shop_id = ANY($1)' : 'o.shop_id = $1';
        const previousPeriod = previousFrom && previousTo
            ? resolveCurrentMonthExpensePeriod(previousFrom, previousTo)
            : null;
        const previousFromKey = previousPeriod
            ? vietnamDateKey(previousPeriod.fromDate)
            : null;
        const previousToKey = previousPeriod
            ? vietnamDateKey(previousPeriod.toDate)
            : null;
        const params: any[] = [
            shopId,
            fromKey,
            toKey,
            previousFromKey,
            previousToKey,
        ];
        const soldNetValueSql = buildAllocatedMerchandiseRevenueSql(
            'oi.subtotal',
            'o',
        );
        const returnedNetValueSql = buildAllocatedMerchandiseRevenueSql(
            'ri.subtotal',
            'returned_order',
        );

        // Rank products by net merchandise revenue and quantity in the period.
        // Order-level discounts are allocated proportionally to every item.
        // Returns use their own business date and the same allocation factor.
        const topProducts = await AppDataSource.query(`
            WITH sold_cost AS (
                SELECT
                    oi.order_id,
                    oi.product_id,
                    CASE
                      WHEN SUM(oi.quantity) = 0 THEN 0
                      ELSE SUM(oi.quantity * oi.cost_price) / SUM(oi.quantity)
                    END AS unit_cost
                FROM sales_order_items oi
                JOIN sales_orders o ON oi.order_id = o.id
                WHERE ${shopCondition}
                  AND o.status != 'CANCELLED'
                  AND EXISTS (
                    SELECT 1
                    FROM sales_returns r
                    WHERE r.order_id = o.id
                      AND r.return_date >= $2
                      AND r.return_date <= $3
                      AND UPPER(COALESCE(r.status, '')) NOT IN ('CANCELLED', 'REJECTED')
                  )
                GROUP BY oi.order_id, oi.product_id
            ), sold AS (
                SELECT
                    p.id,
                    p.name,
                    p.unit,
                    SUM(${soldNetValueSql}) AS gross_value,
                    SUM(oi.quantity) AS gross_quantity,
                    SUM(oi.quantity * oi.cost_price) AS gross_cogs
                FROM sales_order_items oi
                JOIN sales_orders o ON oi.order_id = o.id
                JOIN products p ON oi.product_id = p.id
                WHERE ${shopCondition}
                  AND o.order_date >= $2::date
                  AND o.order_date < ($3::date + interval '1 day')
                  AND o.status != 'CANCELLED'
                GROUP BY p.id, p.name, p.unit
            ), returned AS (
                SELECT
                    ri.product_id,
                    SUM(${returnedNetValueSql}) AS return_value,
                    SUM(ri.quantity) AS return_quantity,
                    SUM(ri.quantity * sold_cost.unit_cost) AS return_cogs
                FROM sales_return_items ri
                JOIN sales_returns r ON ri.return_id = r.id
                JOIN sales_orders returned_order ON returned_order.id = r.order_id
                JOIN sold_cost
                  ON sold_cost.order_id = r.order_id
                  AND sold_cost.product_id = ri.product_id
                WHERE ${isArray ? 'r.shop_id = ANY($1)' : 'r.shop_id = $1'}
                  AND r.return_date >= $2::date
                  AND r.return_date < ($3::date + interval '1 day')
                  AND UPPER(COALESCE(r.status, '')) NOT IN ('CANCELLED', 'REJECTED')
                GROUP BY ri.product_id
            ), previous_sold AS (
                SELECT
                    p.id,
                    SUM(${soldNetValueSql}) AS gross_value
                FROM sales_order_items oi
                JOIN sales_orders o ON oi.order_id = o.id
                JOIN products p ON oi.product_id = p.id
                WHERE ${shopCondition}
                  AND $4::date IS NOT NULL
                  AND $5::date IS NOT NULL
                  AND o.order_date >= $4::date
                  AND o.order_date < ($5::date + interval '1 day')
                  AND o.status != 'CANCELLED'
                GROUP BY p.id
            ), previous_returned AS (
                SELECT
                    ri.product_id,
                    SUM(${returnedNetValueSql}) AS return_value
                FROM sales_return_items ri
                JOIN sales_returns r ON ri.return_id = r.id
                JOIN sales_orders returned_order ON returned_order.id = r.order_id
                WHERE ${isArray ? 'r.shop_id = ANY($1)' : 'r.shop_id = $1'}
                  AND $4::date IS NOT NULL
                  AND $5::date IS NOT NULL
                  AND r.return_date >= $4::date
                  AND r.return_date < ($5::date + interval '1 day')
                  AND UPPER(COALESCE(r.status, '')) NOT IN ('CANCELLED', 'REJECTED')
                GROUP BY ri.product_id
            ), previous_net AS (
                SELECT
                    previous_sold.id,
                    GREATEST(
                      previous_sold.gross_value - COALESCE(previous_returned.return_value, 0),
                      0
                    ) AS value
                FROM previous_sold
                LEFT JOIN previous_returned
                  ON previous_returned.product_id = previous_sold.id
            )
            SELECT
                sold.id,
                sold.name,
                sold.unit,
                GREATEST(sold.gross_value - COALESCE(returned.return_value, 0), 0) AS value,
                GREATEST(sold.gross_quantity - COALESCE(returned.return_quantity, 0), 0) AS quantity,
                GREATEST(sold.gross_cogs - COALESCE(returned.return_cogs, 0), 0) AS cogs,
                (sold.gross_value - COALESCE(returned.return_value, 0)) -
                (sold.gross_cogs - COALESCE(returned.return_cogs, 0)) AS gross_profit,
                previous_net.value AS previous_value
            FROM sold
            LEFT JOIN returned ON returned.product_id = sold.id
            LEFT JOIN previous_net ON previous_net.id = sold.id
            WHERE sold.gross_value - COALESCE(returned.return_value, 0) > 0
            ORDER BY value DESC, quantity DESC, sold.id ASC
            LIMIT 10
        `, params);

        return topProducts.map((p: any) => {
            const value = Number(p.value);
            const previousValue = p.previous_value == null
                ? null
                : Number(p.previous_value);
            const growth = calculateRevenueGrowth(
                value,
                previousValue,
                previousPeriod !== null,
            );
            return {
                id: Number(p.id),
                name: p.name,
                unit: p.unit || 'Sản phẩm',
                value,
                quantity: Number(p.quantity),
                cogs: Number(p.cogs),
                grossProfit: Number(p.gross_profit),
                previousValue,
                marginPct: calculateGrossMarginPercentage(
                    value,
                    Number(p.gross_profit),
                ),
                ...growth,
            };
        });
    }

    async getTopReturnedProducts(
        shopId: number | number[],
        from?: string,
        to?: string,
    ) {
        const { fromDate, toDate } = resolveCurrentMonthExpensePeriod(from, to);
        const fromKey = vietnamDateKey(fromDate);
        const toKey = vietnamDateKey(toDate);
        const shopCondition = Array.isArray(shopId)
            ? 'r.shop_id = ANY($1)'
            : 'r.shop_id = $1';
        const returnedNetValueSql = buildAllocatedMerchandiseRevenueSql(
            'ri.subtotal',
            'returned_order',
        );

        const rows = await AppDataSource.query(`
            SELECT
                p.id,
                p.name,
                p.unit,
                COUNT(DISTINCT r.id)::int AS return_count,
                COALESCE(SUM(ri.quantity), 0) AS quantity,
                COALESCE(SUM(${returnedNetValueSql}), 0) AS value,
                (ARRAY_AGG(
                    COALESCE(
                        NULLIF(BTRIM(ri.reason), ''),
                        NULLIF(BTRIM(r.reason), ''),
                        'Không ghi nhận'
                    )
                    ORDER BY r.return_date DESC, r.id DESC
                ))[1] AS latest_reason
            FROM sales_returns r
            JOIN sales_orders returned_order ON returned_order.id = r.order_id
            JOIN sales_return_items ri ON ri.return_id = r.id
            JOIN products p ON p.id = ri.product_id
            WHERE ${shopCondition}
              AND r.return_date >= $2::date
              AND r.return_date < ($3::date + INTERVAL '1 day')
              AND UPPER(COALESCE(r.status, '')) NOT IN ('CANCELLED', 'REJECTED')
            GROUP BY p.id, p.name, p.unit
            ORDER BY value DESC, quantity DESC, p.id ASC
            LIMIT 5
        `, [shopId, fromKey, toKey]);

        return rows.map((row: any) => ({
            id: Number(row.id),
            name: row.name,
            unit: row.unit || 'Sản phẩm',
            returnCount: Number(row.return_count || 0),
            quantity: Number(row.quantity || 0),
            value: Number(row.value || 0),
            latestReason: row.latest_reason || 'Không ghi nhận',
        }));
    }

    async paymentMethodSummary(shopId: number | number[], from?: string, to?: string) {
        const { fromDate, toDate } = resolveCurrentMonthExpensePeriod(from, to);
        const fromKey = vietnamDateKey(fromDate);
        const toKey = vietnamDateKey(toDate);

        const shopCondition = Array.isArray(shopId) ? 'o.shop_id IN (:...shopIds)' : 'o.shop_id = :shopId';
        const shopParams = Array.isArray(shopId) ? { shopIds: shopId } : { shopId };
        const methods = await this.paymentRepo.createQueryBuilder('p')
            .innerJoin('p.order', 'o')
            .select('p.method', 'method')
            .addSelect('COUNT(p.id)', 'count')
            .addSelect('COALESCE(SUM(p.amount), 0)', 'total')
            .where(`${shopCondition} AND p.paid_at >= CAST(:fromKey AS date) AND p.paid_at < CAST(:toKey AS date) + INTERVAL '1 day' AND o.status != 'CANCELLED'`, { ...shopParams, fromKey, toKey })
            .groupBy('p.method')
            .getRawMany();

        return methods.map(m => ({
            method: m.method || 'UNKNOWN',
            count: Number(m.count || 0),
            total: Number(m.total || 0)
        }));
    }

    async findById(shopId: number, id: number) {
        const order = await this.orderRepo.findOne({
            where: { id, shopId },
            relations: ['customer', 'items', 'items.product', 'payments'],
        });
        if (!order) throw new Error('Order not found');

        const returns = await this.returnRepo.find({
            where: { order: { id, shopId } as any, shopId } as any,
            relations: ['items'],
            order: { createdAt: 'DESC' } as any,
        });

        return { ...(this.withItemProductIds(order) as any), returns };
    }

    async create(shopId: number, dto: any) {
        const queryRunner = AppDataSource.createQueryRunner();
        await queryRunner.connect();
        await queryRunner.startTransaction();
        try {
            const manager = queryRunner.manager;

            const orderDate = dto.orderDate ? new Date(dto.orderDate) : new Date();
            if (Number.isNaN(orderDate.getTime())) {
                throw new Error('Validation: Order date is invalid');
            }

            const customer = dto.customerId
                ? await manager.findOne(Customer, { where: { id: Number(dto.customerId), shopId } })
                : null;
            if (dto.customerId && !customer) {
                throw new Error('Validation: Customer not found');
            }

            let subtotal = 0;
            let totalCogs = 0;
            const rawItems: any[] = Array.isArray(dto.items) ? dto.items : [];
            if (rawItems.length === 0) {
                throw new Error('Validation: Order must contain at least one item');
            }
            const allLotDeductions: { lotId: number; qty: number }[] = [];
            const itemLotDeductions: { itemIndex: number, lotId: number, qty: number }[] = [];
            const stockDeductions: { productId: number; quantity: number }[] = [];

            const items: SalesOrderItem[] = [];
            for (const i of rawItems) {
                const quantity = Number(i.quantity || 0);
                if (!Number.isFinite(quantity) || quantity <= 0) {
                    throw new Error('Validation: Quantity must be greater than 0');
                }

                const product = i.productId
                    ? await manager.findOne(Product, { where: { id: Number(i.productId), shopId } })
                    : null;
                if (!product) throw new Error('Validation: Product not found');
                const unitPrice = assertAllowedUnitPrice(
                    i.unitPrice,
                    product,
                    quantity,
                    orderDate,
                );
                const lineSubtotal = quantity * unitPrice;
                subtotal += lineSubtotal;
                await this.assertStockAvailable(shopId, product.id, quantity, manager);
                stockDeductions.push({ productId: product.id, quantity });

                // Tính giá vốn cho item này
                let costPrice = 0;
                if (product && quantity > 0) {
                    const cogsResult = await this.cogsService.calculateCOGS(
                        product.id,
                        quantity,
                        undefined,
                        shopId,
                    );
                    costPrice = cogsResult.unitCost;
                    totalCogs += cogsResult.totalCost;
                    allLotDeductions.push(...cogsResult.lotDeductions);
                    cogsResult.lotDeductions.forEach(d => {
                        itemLotDeductions.push({ itemIndex: items.length, lotId: d.lotId, qty: d.qty });
                    });
                }

                const item = manager.create(SalesOrderItem, {
                    shopId,
                    quantity,
                    unitPrice,
                    subtotal: lineSubtotal,
                    costPrice,
                    taxRate: Number(product.taxRate || 0),
                    taxAmount: 0,
                    productId: product.id,
                });
                items.push(item);
            }

            const discountAmount = Number(dto.discountAmount || 0);
            if (
                !Number.isFinite(discountAmount)
                || discountAmount < 0
                || discountAmount > subtotal
            ) {
                throw new Error('Validation: Discount must be between 0 and subtotal');
            }
            const taxCalculation = calculateSalesTaxLines(
                items.map(item => ({
                    subtotal: Number(item.subtotal),
                    taxRate: Number(item.taxRate),
                })),
                subtotal,
                discountAmount,
            );
            taxCalculation.lines.forEach((line, index) => {
                items[index].taxAmount = line.taxAmount;
            });
            const taxAmount = taxCalculation.taxAmount;
            const totalAmount = subtotal - discountAmount + taxAmount;
            const paidAmount = dto.settleInFull === true
                ? totalAmount
                : Number(dto.paidAmount || 0);
            if (
                !Number.isFinite(paidAmount)
                || paidAmount < 0
                || paidAmount > totalAmount
            ) {
                throw new Error('Validation: Paid amount must be between 0 and order total');
            }
            const accountingSplit = calculateSalesAccountingSplit(
                subtotal,
                discountAmount,
                taxAmount,
                paidAmount,
            );
            const unpaidAmount = accountingSplit.receivableAmount;
            if (unpaidAmount > 0 && !customer) {
                throw new Error('Validation: Customer is required for an unpaid order');
            }
            const settledPaymentMethod = paidAmount > 0
                ? normalizeSettledPaymentMethod(dto.paymentMethod || 'CASH')
                : String(dto.paymentMethod || 'CASH').toUpperCase();

            if (
                customer
                && unpaidAmount > 0
                && Number(customer.creditLimit || 0) > 0
            ) {
                const existingDebtRaw = await manager.createQueryBuilder(Receivable, 'r')
                    .select('COALESCE(SUM(r.amount - r.paid_amount), 0)', 'remainingDebt')
                    .where('r.customer_id = :customerId AND r.shop_id = :shopId', { customerId: customer.id, shopId })
                    .andWhere("UPPER(COALESCE(r.status, '')) NOT IN ('PAID', 'CANCELLED')")
                    .getRawOne();

                const existingDebt = Number(existingDebtRaw?.remainingDebt || 0);
                const currentExposure = Math.max(Number(customer.balance || 0), existingDebt);
                const newDebt = unpaidAmount;
                const projectedExposure = currentExposure + newDebt;
                const creditLimit = Number(customer.creditLimit || 0);

                if (projectedExposure > creditLimit) {
                    throw new Error(`Vượt hạn mức tín dụng: công nợ dự kiến ${projectedExposure.toFixed(0)} > hạn mức ${creditLimit.toFixed(0)}`);
                }
            }

            const order = manager.create(SalesOrder, {
                shopId,
                orderCode: dto.orderCode || 'SO' + Date.now().toString().slice(-6),
                orderDate,
                status: paidAmount >= totalAmount ? 'DELIVERED' : 'PENDING',
                subtotal,
                discountAmount,
                taxAmount,
                totalAmount,
                totalCogs,
                paidAmount,
                paymentMethod: settledPaymentMethod,
                notes: dto.notes,
                invoiceNumber: dto.invoiceNumber,
                ...(customer ? { customer } : {}),
                items,
                createdBy: dto.createdBy,
            });

            const savedOrder = await manager.save(SalesOrder, order);

            if (itemLotDeductions.length > 0) {
                const slDs = itemLotDeductions.map(d => manager.create(SalesOrderLotDeduction, {
                    orderId: savedOrder.id,
                    orderItemId: savedOrder.items[d.itemIndex].id,
                    lotId: d.lotId,
                    quantity: d.qty
                }));
                await manager.save(SalesOrderLotDeduction, slDs);
            }

            if (paidAmount > 0) {
                await manager.save(SalesOrderPayment, manager.create(SalesOrderPayment, {
                    shopId,
                    order: savedOrder,
                    amount: paidAmount,
                    method: settledPaymentMethod,
                    referenceCode: dto.qrPaymentRef,
                    notes: 'Thanh toán khi tạo đơn hàng'
                }));

                await this.financeService.createCashTransaction(shopId, {
                    transactionCode: `TS${shopId}${savedOrder.id}`,
                    amount: paidAmount,
                    type: 'INCOME',
                    category: 'SALES',
                    paymentMethod: settledPaymentMethod,
                    referenceType: 'SALES_ORDER',
                    referenceId: savedOrder.id,
                    referenceCode: savedOrder.orderCode,
                    description: `Thanh toán cho đơn hàng ${savedOrder.orderCode}`,
                    transactionDate: savedOrder.orderDate,
                    status: 'COMPLETED',
                    createdBy: dto.createdBy
                } as any, manager);
            }

            if (unpaidAmount > 0 && customer) {
                const receivable = manager.create(Receivable, {
                    shopId,
                    customer,
                    orderId: savedOrder.id,
                    amount: unpaidAmount,
                    paidAmount: 0,
                    dueDate: new Date(new Date().setDate(new Date().getDate() + 30)),
                    status: 'UNPAID',
                    notes: `Công nợ từ đơn hàng ${savedOrder.orderCode}`
                });
                await manager.save(Receivable, receivable);

                customer.balance = Number(customer.balance || 0) + unpaidAmount;
                await manager.save(Customer, customer);
            }

            // Commit: trừ tồn kho các lô
            if (allLotDeductions.length > 0) {
                await this.cogsService.commitLotDeductions(allLotDeductions, manager);
            }
            if (stockDeductions.length > 0) {
                await this.commitStockDeductions(shopId, stockDeductions, savedOrder.id, manager);
            }

            // === Journal Ledger: Ghi bút toán kép cho đơn hàng ===
            const journalLines: { accountCode: string; amount: number; entryType: 'DEBIT' | 'CREDIT' }[] = [];

            const netSalesAmount = accountingSplit.netSales;
            journalLines.push({
                accountCode: '511',
                amount: netSalesAmount,
                entryType: 'CREDIT',
            });
            if (taxAmount > 0) {
                journalLines.push({
                    accountCode: '3331',
                    amount: taxAmount,
                    entryType: 'CREDIT',
                });
            }

            // Tiền đã thu: tiền mặt vào 111, chuyển khoản/QR/thẻ vào 112.
            if (paidAmount > 0) {
                journalLines.push({
                    accountCode: paymentLedgerAccountCode(settledPaymentMethod),
                    amount: paidAmount,
                    entryType: 'DEBIT',
                });
            }

            // Phải thu khách hàng: Nợ TK 131
            if (unpaidAmount > 0 && customer) {
                journalLines.push({ accountCode: '131', amount: unpaidAmount, entryType: 'DEBIT' });
            }

            // Giá vốn hàng bán: Nợ TK 632, Có TK 156 (Hàng hóa)
            if (totalCogs > 0) {
                journalLines.push({ accountCode: '632', amount: totalCogs, entryType: 'DEBIT' });
                journalLines.push({ accountCode: '156', amount: totalCogs, entryType: 'CREDIT' });
            }

            await this.postingService.postJournal(
                shopId,
                'SALES_ORDER',
                savedOrder.id,
                `Bán hàng - Đơn ${savedOrder.orderCode}`,
                journalLines,
                manager
            );

            await queryRunner.commitTransaction();
            return this.findById(shopId, savedOrder.id);
        } catch (error) {
            await queryRunner.rollbackTransaction();
            throw error;
        } finally {
            await queryRunner.release();
        }
    }

    async cancel(shopId: number, id: number, createdBy?: number) {
        const queryRunner = AppDataSource.createQueryRunner();
        await queryRunner.connect();
        await queryRunner.startTransaction();

        try {
            const manager = queryRunner.manager;
            const order = await manager.findOne(SalesOrder, { where: { id, shopId } });
            if (!order) throw new Error('Order not found');
            if (order.status === 'CANCELLED') {
                throw new Error('Validation: Order is already cancelled');
            }
            
            order.status = 'CANCELLED';
            await manager.save(SalesOrder, order);

            const receivable = await manager.findOne(Receivable, { 
                where: { shopId, orderId: id } as any, 
                relations: ['customer'] 
            });
            if (receivable && receivable.status !== 'CANCELLED') {
                receivable.status = 'CANCELLED';
                await manager.save(Receivable, receivable);

                const unpaidAmount = Number(receivable.amount) - Number(receivable.paidAmount || 0);
                if (unpaidAmount > 0 && receivable.customer) {
                    const customer = await manager.findOne(Customer, { where: { id: receivable.customer.id, shopId } });
                    if (customer) {
                        customer.balance = Math.max(
                            Number(customer.balance || 0) - unpaidAmount,
                            0,
                        );
                        await manager.save(Customer, customer);
                    }
                }
            }

            // === Reverse FIFO: Hoàn trả số lượng vào lô hàng ===
            const lotDeductionRepo = manager.getRepository(SalesOrderLotDeduction);
            const lotRepo = manager.getRepository(InventoryLot);
            const deductions = await lotDeductionRepo.find({ where: { orderId: id } });
            
            for (const d of deductions) {
                const lot = await lotRepo.findOne({ where: { id: d.lotId } });
                if (lot) {
                    lot.remainingQty = Number(lot.remainingQty) + Number(d.quantity);
                    await lotRepo.save(lot);
                }
            }
            // Xóa các deductions
            if (deductions.length > 0) {
                await lotDeductionRepo.remove(deductions);
            }

            // === Hoàn trả Inventory Stocks ===
            const movementRepo = manager.getRepository(InventoryMovement);
            const stockRepo = manager.getRepository(InventoryStock);
            const outMovements = await movementRepo.find({ where: { shopId, referenceType: 'SALES_ORDER', referenceId: id, movementType: 'OUT' } as any });
            
            for (const mov of outMovements) {
                // Tạo movement IN
                await movementRepo.save(movementRepo.create({
                    shopId,
                    productId: mov.productId,
                    warehouseId: mov.warehouseId,
                    movementType: 'IN',
                    quantity: mov.quantity,
                    referenceType: 'SALES_ORDER_CANCEL',
                    referenceId: id,
                    notes: `Hoàn trả từ đơn hàng ${order.orderCode} bị hủy`
                }));
                // Tăng stock
                const stock = await stockRepo.findOne({ where: { shopId, productId: mov.productId, warehouseId: mov.warehouseId } as any });
                if (stock) {
                    stock.quantity = Number(stock.quantity) + Number(mov.quantity);
                    stock.updatedAt = new Date();
                    await stockRepo.save(stock);
                }
            }

            // === Journal Ledger: Đánh dấu bút toán gốc là đã hủy ===
            const journalEntryRepo = manager.getRepository(JournalEntry);
            const originalEntry = await journalEntryRepo.findOne({
                where: { shopId, referenceType: 'SALES_ORDER', referenceId: id }
            });
            if (originalEntry && !originalEntry.isVoided) {
                originalEntry.isVoided = true;
                await journalEntryRepo.save(originalEntry);
            }

            const settledPayments = await manager.find(SalesOrderPayment, {
                where: { shopId, order: { id } },
            });
            const refunds = groupSettledPaymentsByMethod(settledPayments);
            for (const refund of refunds) {
                await this.financeService.createCashTransaction(shopId, {
                    amount: refund.amount,
                    type: 'EXPENSE',
                    category: 'REFUND',
                    paymentMethod: refund.method,
                    referenceType: 'SALES_ORDER_CANCEL',
                    referenceId: order.id,
                    referenceCode: order.orderCode,
                    description: `Hoàn tiền ${refund.method} do hủy đơn ${order.orderCode}`,
                    transactionDate: new Date(),
                    status: 'COMPLETED',
                    createdBy,
                } as any, manager);
            }

            const collectionEntries = await journalEntryRepo.find({
                where: {
                    shopId,
                    referenceType: 'DEBT_COLLECTION',
                    referenceId: id,
                    isVoided: false,
                },
            });
            for (const entry of collectionEntries) {
                entry.isVoided = true;
            }
            if (collectionEntries.length > 0) {
                await journalEntryRepo.save(collectionEntries);
            }

            await queryRunner.commitTransaction();
            return this.findById(shopId, id);
        } catch (error) {
            await queryRunner.rollbackTransaction();
            throw error;
        } finally {
            await queryRunner.release();
        }
    }

    async updateOrder(shopId: number, id: number, dto: Partial<SalesOrder>) {
        const order = await this.orderRepo.findOne({ where: { id, shopId } });
        if (!order) throw new Error('Order not found');
        if (dto.status !== undefined || dto.paymentMethod !== undefined) {
            throw new Error('Validation: Financial fields must use the payment or cancellation workflow');
        }
        const allowedFields: (keyof SalesOrder)[] = ['notes', 'invoiceNumber'];
        for (const field of allowedFields) {
            if (dto[field] !== undefined) {
                (order as any)[field] = dto[field];
            }
        }
        await this.orderRepo.save(order);
        return this.findById(shopId, id);
    }

    async addPayment(shopId: number, orderId: number, dto: Partial<SalesOrderPayment>) {
        const queryRunner = AppDataSource.createQueryRunner();
        await queryRunner.connect();
        await queryRunner.startTransaction();

        try {
            const manager = queryRunner.manager;
            const order = await manager.findOne(SalesOrder, { where: { id: orderId, shopId } });
            if (!order) throw new Error('Order not found');
            if (order.status === 'CANCELLED') {
                throw new Error('Validation: Cannot pay a cancelled order');
            }
            if (order.returnStatus && order.returnStatus !== 'NONE') {
                throw new Error('Validation: Cannot pay a returned order');
            }
            const amount = Number(dto.amount || 0);
            if (amount <= 0) throw new Error('Validation: Payment amount must be greater than 0');
            const currentPaid = Number(order.paidAmount || 0);
            const totalAmount = Number(order.totalAmount || 0);
            if (currentPaid + amount > totalAmount) {
                throw new Error('Validation: Payment amount exceeds remaining order balance');
            }
            const settledMethod = normalizeSettledPaymentMethod(
                (dto as any).method || 'CASH',
            );
            const payment = await manager.save(SalesOrderPayment, manager.create(SalesOrderPayment, {
                ...dto,
                method: settledMethod,
                shopId,
                order,
            }));
            order.paidAmount = currentPaid + amount;
            order.status = (Number(order.paidAmount) >= totalAmount) ? 'DELIVERED' : 'PENDING';
            await manager.save(SalesOrder, order);

            await this.financeService.createCashTransaction(shopId, {
                amount,
                type: 'INCOME',
                category: 'SALES',
                paymentMethod: settledMethod,
                referenceType: 'SALES_ORDER',
                referenceId: order.id,
                referenceCode: order.orderCode,
                description: `Thanh toán thêm cho đơn hàng ${order.orderCode}`,
                transactionDate: new Date(),
                status: 'COMPLETED',
                createdBy: (dto as any).createdBy
            } as any, manager);

            // === Journal Ledger: Thu nợ khách hàng (Nợ TK 111 / Có TK 131) ===
            await this.postingService.postJournal(
                shopId,
                'DEBT_COLLECTION',
                order.id,
                `Thu nợ khách hàng - Đơn ${order.orderCode}`,
                [
                    {
                        accountCode: paymentLedgerAccountCode(settledMethod),
                        amount,
                        entryType: 'DEBIT',
                    },
                    { accountCode: '131', amount, entryType: 'CREDIT' },
                ],
                manager
            );

            // Cập nhật Receivable nếu tồn tại
            const receivable = await manager.findOne(Receivable, {
                where: { shopId, orderId } as any,
                relations: ['customer'],
            });
            if (receivable && receivable.status !== 'PAID' && receivable.status !== 'CANCELLED') {
                const debtPayment = applyDebtPayment(
                    Number(receivable.amount),
                    Number(receivable.paidAmount || 0),
                    amount,
                );
                receivable.paidAmount = debtPayment.paidAmount;
                receivable.status = debtPayment.status;
                await manager.save(Receivable, receivable);
                await manager.save(
                    DebtPaymentHistory,
                    manager.create(DebtPaymentHistory, {
                        shopId,
                        receivable,
                        amount,
                        paymentMethod: settledMethod,
                        paymentDate: new Date(),
                        notes: (dto as any).notes,
                        recordedBy: (dto as any).createdBy,
                    }),
                );

                // Giảm số dư nợ khách hàng
                const customer =
                    receivable.customer?.shopId === shopId
                        ? receivable.customer
                        : undefined;
                if (customer) {
                    customer.balance = Math.max(Number(customer.balance || 0) - amount, 0);
                    await manager.save(Customer, customer);
                }
            }

            await queryRunner.commitTransaction();
            return payment;
        } catch (error) {
            await queryRunner.rollbackTransaction();
            throw error;
        } finally {
            await queryRunner.release();
        }
    }

    async createReturn(shopId: number, orderId: number, dto: any) {
        const queryRunner = AppDataSource.createQueryRunner();
        await queryRunner.connect();
        await queryRunner.startTransaction();

        try {
            const manager = queryRunner.manager;
            const order = await manager.findOne(SalesOrder, {
                where: { id: orderId, shopId },
                relations: ['items', 'items.product'],
            });
            if (!order) throw new Error('Order not found');
            if (order.status === 'CANCELLED') throw new Error('Cannot return a cancelled order');
            if (order.returnStatus && order.returnStatus !== 'NONE') {
                throw new Error('Validation: Order has already been returned');
            }

            const returnDate = dto.returnDate ? new Date(dto.returnDate) : new Date();

            const rawItems: any[] = Array.isArray(dto.items) ? dto.items : [];
            if (rawItems.length === 0) {
                throw new Error('Validation: Return items are required');
            }
            const soldItems = new Map(
                order.items.map((item) => [item.product?.id, item]),
            );
            let returnedCogs = 0;
            let returnedQuantity = 0;
            const normalizedReturnItems: Array<{
                productId: number;
                quantity: number;
                unitPrice: number;
                subtotal: number;
                reason?: string;
            }> = [];
            const seenProductIds = new Set<number>();
            for (const rawItem of rawItems) {
                const productId = Number(rawItem.productId);
                const quantity = Number(rawItem.quantity || 0);
                const soldItem = soldItems.get(productId);
                if (
                    !soldItem ||
                    seenProductIds.has(productId) ||
                    quantity !== Number(soldItem.quantity)
                ) {
                    throw new Error('Validation: Return quantity exceeds sold quantity');
                }
                seenProductIds.add(productId);
                returnedQuantity += quantity;
                returnedCogs += quantity * Number(soldItem.costPrice || 0);
                normalizedReturnItems.push({
                    productId,
                    quantity,
                    unitPrice: Number(soldItem.unitPrice || 0),
                    subtotal: Number(soldItem.subtotal || 0),
                    reason: rawItem.reason,
                });
            }
            const soldQuantity = order.items.reduce(
                (sum, item) => sum + Number(item.quantity || 0),
                0,
            );
            if (
                returnedQuantity !== soldQuantity ||
                rawItems.length !== order.items.length
            ) {
                throw new Error('Validation: Partial returns are not supported yet');
            }
            const settledPayments = await manager.find(SalesOrderPayment, {
                where: { shopId, order: { id: orderId } },
            });
            const refunds = groupSettledPaymentsByMethod(settledPayments);
            const recordedPaymentTotal = refunds.reduce(
                (sum, refund) => sum + refund.amount,
                0,
            );
            const paidAmount = Number(order.paidAmount || 0);
            if (recordedPaymentTotal + 0.01 < paidAmount) {
                const fallbackMethod = normalizeSettledPaymentMethod(
                    order.paymentMethod || dto.refundMethod || 'CASH',
                );
                const missingAmount = paidAmount - recordedPaymentTotal;
                const existing = refunds.find((entry) => entry.method === fallbackMethod);
                if (existing) existing.amount += missingAmount;
                else refunds.push({ method: fallbackMethod, amount: missingAmount });
            }
            const refundAmount = refunds.reduce(
                (sum, refund) => sum + refund.amount,
                0,
            );
            if (
                dto.refundAmount != null &&
                Math.abs(Number(dto.refundAmount) - refundAmount) > 0.01
            ) {
                throw new Error('Validation: Full return must refund the full amount paid');
            }

            const entity = manager.create(SalesReturn, {
                shopId,
                returnCode: dto.returnCode || 'RT' + Date.now().toString().slice(-6),
                order,
                returnDate,
                reason: dto.reason || '',
                refundAmount,
                refundMethod: refunds.length === 1 ? refunds[0].method : 'MULTIPLE',
                status: 'COMPLETED',
                notes: dto.notes,
            } as any);

            if (normalizedReturnItems.length) {
                (entity as any).items = [];
                for (const item of normalizedReturnItems) {
                    const product = item.productId
                        ? await manager.findOne(Product, { where: { id: item.productId, shopId } })
                        : null;

                    const returnItem = manager.create(SalesReturnItem, {
                        shopId,
                        ...(product ? { product } : {}),
                        quantity: item.quantity,
                        unitPrice: item.unitPrice,
                        subtotal: item.subtotal,
                        reason: item.reason,
                    });
                    (entity as any).items.push(returnItem);
                }
            }

            const savedReturn = await manager.save(SalesReturn, entity) as unknown as SalesReturn;

            order.returnStatus = 'FULL_RETURN';
            await manager.save(SalesOrder, order);

            const receivable = await manager.findOne(Receivable, {
                where: { shopId, orderId } as any,
                relations: ['customer'],
            });
            if (receivable && receivable.status !== 'CANCELLED') {
                const unpaidAmount = Math.max(
                    Number(receivable.amount) - Number(receivable.paidAmount || 0),
                    0,
                );
                receivable.status = 'CANCELLED';
                await manager.save(Receivable, receivable);
                if (unpaidAmount > 0 && receivable.customer) {
                    receivable.customer.balance = Math.max(
                        Number(receivable.customer.balance || 0) - unpaidAmount,
                        0,
                    );
                    await manager.save(Customer, receivable.customer);
                }
            }

            // === Hoàn trả Inventory Stocks & Lots (Reverse FIFO) ===
            const lotDeductionRepo = manager.getRepository(SalesOrderLotDeduction);
            const lotRepo = manager.getRepository(InventoryLot);
            const stockRepo = manager.getRepository(InventoryStock);
            const movementRepo = manager.getRepository(InventoryMovement);

            const itemsToProcess = (entity as any).items || [];
            for (const item of itemsToProcess) {
                let remainingToReturn = Number(item.quantity);
                if (remainingToReturn <= 0 || !item.product) continue;

                // 1. Tăng stock & ghi movement
                // Tìm warehouse từ movement OUT lúc mua, hoặc default warehouse
                const movOut = await movementRepo.findOne({
                    where: { shopId, referenceType: 'SALES_ORDER', referenceId: orderId, productId: item.product.id, movementType: 'OUT' } as any
                });
                if (movOut) {
                    await movementRepo.save(movementRepo.create({
                        shopId,
                        productId: item.product.id,
                        warehouseId: movOut.warehouseId,
                        movementType: 'IN',
                        quantity: remainingToReturn,
                        referenceType: 'SALES_RETURN',
                        referenceId: savedReturn.id,
                        notes: `Hoàn trả từ phiếu trả hàng ${savedReturn.returnCode}`
                    }));
                    const stock = await stockRepo.findOne({ where: { shopId, productId: item.product.id, warehouseId: movOut.warehouseId } as any });
                    if (stock) {
                        stock.quantity = Number(stock.quantity) + remainingToReturn;
                        stock.updatedAt = new Date();
                        await stockRepo.save(stock);
                    }
                }

                // 2. Hoàn lô hàng
                const deductions = await lotDeductionRepo.find({
                    where: { orderId: orderId },
                    relations: ['orderItem', 'orderItem.product']
                });
                const itemDeductions = deductions.filter(d => d.orderItem?.product?.id === item.product?.id);
                // Ưu tiên hoàn vào lô trừ gần nhất (Reverse FIFO)
                itemDeductions.sort((a, b) => b.id - a.id);

                for (const d of itemDeductions) {
                    if (remainingToReturn <= 0) break;
                    const returnQty = Math.min(Number(d.quantity), remainingToReturn);
                    
                    const lot = await lotRepo.findOne({ where: { id: d.lotId } });
                    if (lot) {
                        lot.remainingQty = Number(lot.remainingQty) + returnQty;
                        await lotRepo.save(lot);
                    }
                    d.quantity = Number(d.quantity) - returnQty;
                    if (d.quantity <= 0) {
                        await lotDeductionRepo.remove(d);
                    } else {
                        await lotDeductionRepo.save(d);
                    }
                    remainingToReturn -= returnQty;
                }
            }

            for (const refund of refunds) {
                await this.financeService.createCashTransaction(shopId, {
                    amount: refund.amount,
                    type: 'EXPENSE',
                    category: 'REFUND',
                    paymentMethod: refund.method,
                    referenceType: 'SALES_RETURN',
                    referenceId: savedReturn.id,
                    referenceCode: savedReturn.returnCode,
                    description: `Hoàn tiền cho khách trả hàng ${savedReturn.returnCode} (Đơn ${order.orderCode})`,
                    transactionDate: savedReturn.returnDate,
                    status: 'COMPLETED',
                    createdBy: (dto as any).createdBy
                } as any, manager);
            }

            const accountingSplit = calculateSalesAccountingSplit(
                Number(order.subtotal || 0),
                Number(order.discountAmount || 0),
                Number(order.taxAmount || 0),
                paidAmount,
            );
            const netSalesAmount = accountingSplit.netSales;
            const taxAmount = accountingSplit.taxAmount;
            const unpaidAmount = accountingSplit.receivableAmount;
            const returnJournalLines: {
                accountCode: string;
                amount: number;
                entryType: 'DEBIT' | 'CREDIT';
            }[] = [];
            if (netSalesAmount > 0) {
                returnJournalLines.push({
                    accountCode: '511',
                    amount: netSalesAmount,
                    entryType: 'DEBIT',
                });
            }
            if (taxAmount > 0) {
                returnJournalLines.push({
                    accountCode: '3331',
                    amount: taxAmount,
                    entryType: 'DEBIT',
                });
            }
            for (const refund of refunds) {
                returnJournalLines.push({
                    accountCode: paymentLedgerAccountCode(refund.method),
                    amount: refund.amount,
                    entryType: 'CREDIT',
                });
            }
            if (unpaidAmount > 0) {
                returnJournalLines.push({
                    accountCode: '131',
                    amount: unpaidAmount,
                    entryType: 'CREDIT',
                });
            }
            if (returnedCogs > 0) {
                returnJournalLines.push(
                    { accountCode: '156', amount: returnedCogs, entryType: 'DEBIT' },
                    { accountCode: '632', amount: returnedCogs, entryType: 'CREDIT' },
                );
            }
            await this.postingService.postJournal(
                shopId,
                'SALES_RETURN',
                savedReturn.id,
                `Trả hàng - ${savedReturn.returnCode} (Đơn ${order.orderCode})`,
                returnJournalLines,
                manager,
            );

            await queryRunner.commitTransaction();
            return savedReturn;
        } catch (error) {
            await queryRunner.rollbackTransaction();
            throw error;
        } finally {
            await queryRunner.release();
        }
    }

    private async assertStockAvailable(shopId: number, productId: number, quantity: number, manager?: EntityManager) {
        const qb = manager
            ? manager.createQueryBuilder(InventoryStock, 's')
            : this.stockRepo.createQueryBuilder('s');
        qb.select('COALESCE(SUM(s.quantity), 0)', 'available')
            .where('s.shop_id = :shopId AND s.product_id = :productId', { shopId, productId });
        const raw = await qb.getRawOne();
        const available = Number(raw?.available || 0);
        if (available < quantity) {
            throw new Error(`Validation: Insufficient stock for product ${productId}: ${available} available, ${quantity} requested`);
        }
    }

    private withItemProductIds(order: SalesOrder) {
        if (Array.isArray((order as any).items)) {
            (order as any).items = (order as any).items.map((item: any) => ({
                ...item,
                productId: item.productId ?? item.product?.id ?? null,
            }));
        }
        return order;
    }

    private async commitStockDeductions(shopId: number, deductions: { productId: number; quantity: number }[], orderId: number, manager?: EntityManager) {
        const stockRepo = manager ? manager.getRepository(InventoryStock) : this.stockRepo;
        const movementRepo = manager ? manager.getRepository(InventoryMovement) : this.movementRepo;

        for (const deduction of deductions) {
            let remaining = deduction.quantity;
            const stocks = await stockRepo.find({
                where: { shopId, productId: deduction.productId } as any,
                order: { updatedAt: 'ASC', id: 'ASC' } as any,
            });

            for (const stock of stocks) {
                if (remaining <= 0) break;
                const available = Number(stock.quantity || 0);
                if (available <= 0) continue;

                const take = Math.min(available, remaining);
                stock.quantity = available - take;
                stock.updatedAt = new Date();
                await stockRepo.save(stock);
                await movementRepo.save(movementRepo.create({
                    shopId,
                    productId: deduction.productId,
                    warehouseId: stock.warehouseId,
                    movementType: 'OUT',
                    quantity: take,
                    referenceType: 'SALES_ORDER',
                    referenceId: orderId,
                    notes: `Sales order #${orderId}`,
                }));
                remaining -= take;
            }

            if (remaining > 0) {
                throw new Error(`Validation: Unable to deduct full stock for product ${deduction.productId}`);
            }
        }
    }
}
