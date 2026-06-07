import { AppDataSource } from '../config/db.config';
import { SalesOrder, SalesOrderItem, SalesReturn, SalesReturnItem, SalesOrderPayment, SalesOrderLotDeduction } from '../sales/entities';
import { Customer, Receivable } from '../customer/entities';
import { Product } from '../product/entities';
import { COGSService } from './cogs.service';
import { FinanceService } from './finance.service';
import { PostingService } from './posting.service';
import { JournalEntry } from '../finance/ledger.entity';
import { InventoryMovement, InventoryStock } from '../inventory/entities';
import { InventoryLot } from '../inventory/lot.entity';
import { EntityManager } from 'typeorm';

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

    async findAll(shopId: number, page = 1, limit = 20, customerId?: number) {
        const whereClause: any = { shopId };
        if (customerId) {
            whereClause.customer = { id: customerId };
        }
        const [items, total] = await this.orderRepo.findAndCount({ 
            where: whereClause, 
            relations: ['customer'],
            skip: (page - 1) * limit, 
            take: limit, 
            order: { createdAt: 'DESC' } 
        });
        return { items, total, page, limit, totalPages: Math.ceil(total / limit) };
    }
    
    async summary(shopId: number | number[], from?: string, to?: string, userId?: number, isOwner?: boolean) {
        const fromDate = from ? new Date(from) : new Date(new Date().getFullYear(), new Date().getMonth(), 1);
        const toDate = to ? new Date(to) : new Date();
        toDate.setHours(23, 59, 59, 999);

        const shopCondition = Array.isArray(shopId) ? 'o.shop_id IN (:...shopIds)' : 'o.shop_id = :shopId';
        const shopParams = Array.isArray(shopId) ? { shopIds: shopId } : { shopId };
        const userCondition = !isOwner && userId ? ' AND o.created_by = :userId' : '';

        const result = await this.orderRepo.createQueryBuilder('o')
            .select('COALESCE(SUM(o.total_amount), 0)', 'totalRevenue')
            .addSelect('COALESCE(SUM(o.total_cogs), 0)', 'totalCogs')
            .addSelect('COUNT(o.id)', 'orderCount')
            .where(`${shopCondition}${userCondition} AND o.order_date >= :fromDate AND o.order_date <= :toDate AND o.status != 'CANCELLED'`, { ...shopParams, fromDate, toDate, userId })
            .getRawOne();

        const diffDays = Math.ceil((toDate.getTime() - fromDate.getTime()) / (1000 * 3600 * 24));
        const dateFormat = diffDays > 60 ? 'YYYY-MM' : 'YYYY-MM-DD';

        const daily = await this.orderRepo.createQueryBuilder('o')
            .select(`TO_CHAR(o.order_date, '${dateFormat}')`, 'date')
            .addSelect('COALESCE(SUM(o.total_amount), 0)', 'revenue')
            .addSelect('COUNT(o.id)', 'orderCount')
            .where(`${shopCondition}${userCondition} AND o.order_date >= :fromDate AND o.order_date <= :toDate AND o.status != 'CANCELLED'`, { ...shopParams, fromDate, toDate, userId })
            .groupBy(`TO_CHAR(o.order_date, '${dateFormat}')`)
            .orderBy(`TO_CHAR(o.order_date, '${dateFormat}')`, 'ASC')
            .getRawMany();

        return {
            totalRevenue: Number(result?.totalRevenue || 0),
            totalCogs: Number(result?.totalCogs || 0),
            grossProfit: Number(result?.totalRevenue || 0) - Number(result?.totalCogs || 0),
            orderCount: Number(result?.orderCount || 0),
            daily: daily.map(d => ({
                date: d.date,
                revenue: Number(d.revenue || 0),
                orderCount: Number(d.orderCount || 0)
            }))
        };
    }

    async getTopProducts(shopId: number | number[], from?: string, to?: string, userId?: number, isOwner?: boolean) {
        const fromDate = from ? new Date(from) : new Date(new Date().getFullYear(), new Date().getMonth(), 1);
        const toDate = to ? new Date(to) : new Date();
        toDate.setHours(23, 59, 59, 999);

        const isArray = Array.isArray(shopId);
        const shopCondition = isArray ? 'o.shop_id = ANY($1)' : 'o.shop_id = $1';
        const userCondition = !isOwner && userId ? ' AND o.created_by = $4' : '';

        const params: any[] = isArray ? [shopId, fromDate, toDate] : [shopId, fromDate, toDate];
        if (!isOwner && userId) params.push(userId);

        // Query top 5 selling products by revenue
        const topProducts = await AppDataSource.query(`
            SELECT 
                p.name, 
                SUM(oi.subtotal) as value 
            FROM sales_order_items oi
            JOIN sales_orders o ON oi.order_id = o.id
            JOIN products p ON oi.product_id = p.id
            WHERE ${shopCondition} 
              AND o.order_date >= $2 
              AND o.order_date <= $3 
              ${userCondition}
              AND o.status != 'CANCELLED'
            GROUP BY p.id, p.name
            ORDER BY value DESC
            LIMIT 5
        `, params);

        return topProducts.map((p: any) => ({
            name: p.name,
            value: Number(p.value)
        }));
    }

    async paymentMethodSummary(shopId: number | number[], from?: string, to?: string, userId?: number, isOwner?: boolean) {
        const fromDate = from ? new Date(from) : new Date(new Date().getFullYear(), new Date().getMonth(), 1);
        const toDate = to ? new Date(to) : new Date();
        toDate.setHours(23, 59, 59, 999);

        const shopCondition = Array.isArray(shopId) ? 'o.shop_id IN (:...shopIds)' : 'o.shop_id = :shopId';
        const shopParams = Array.isArray(shopId) ? { shopIds: shopId } : { shopId };
        const userCondition = !isOwner && userId ? ' AND o.created_by = :userId' : '';

        const methods = await this.orderRepo.createQueryBuilder('o')
            .select('o.payment_method', 'method')
            .addSelect('COUNT(o.id)', 'count')
            .addSelect('COALESCE(SUM(o.total_amount), 0)', 'total')
            .where(`${shopCondition}${userCondition} AND o.order_date >= :fromDate AND o.order_date <= :toDate AND o.status != 'CANCELLED'`, { ...shopParams, fromDate, toDate, userId })
            .groupBy('o.payment_method')
            .getRawMany();

        return methods.map(m => ({
            method: m.method || 'UNKNOWN',
            count: Number(m.count || 0),
            total: Number(m.total || 0)
        }));
    }

    async findById(shopId: number, id: number) {
        const order = await this.orderRepo.findOne({ where: { id, shopId }, relations: ['items', 'items.product', 'payments'] });
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

            const customer = dto.customerId
                ? await manager.findOne(Customer, { where: { id: Number(dto.customerId), shopId } })
                : null;

            let subtotal = 0;
            let totalCogs = 0;
            const rawItems: any[] = Array.isArray(dto.items) ? dto.items : [];
            const allLotDeductions: { lotId: number; qty: number }[] = [];
            const itemLotDeductions: { itemIndex: number, lotId: number, qty: number }[] = [];
            const stockDeductions: { productId: number; quantity: number }[] = [];

            const items: SalesOrderItem[] = [];
            for (const i of rawItems) {
                const quantity = Number(i.quantity || 0);
                const unitPrice = Number(i.unitPrice || 0);
                if (quantity <= 0) throw new Error('Validation: Quantity must be greater than 0');
                if (unitPrice < 0) throw new Error('Validation: Unit price cannot be negative');
                const lineSubtotal = quantity * unitPrice;
                subtotal += lineSubtotal;

                const product = i.productId
                    ? await manager.findOne(Product, { where: { id: Number(i.productId), shopId } })
                    : null;
                if (!product) throw new Error('Validation: Product not found');
                await this.assertStockAvailable(shopId, product.id, quantity, manager);
                stockDeductions.push({ productId: product.id, quantity });

                // Tính giá vốn cho item này
                let costPrice = 0;
                if (product && quantity > 0) {
                    try {
                        const cogsResult = await this.cogsService.calculateCOGS(product.id, quantity, undefined, shopId);
                        costPrice = cogsResult.unitCost;
                        totalCogs += cogsResult.totalCost;
                        allLotDeductions.push(...cogsResult.lotDeductions);
                        cogsResult.lotDeductions.forEach(d => {
                            itemLotDeductions.push({ itemIndex: items.length, lotId: d.lotId, qty: d.qty });
                        });
                    } catch {
                        costPrice = Number(product.costPrice || 0);
                        totalCogs += costPrice * quantity;
                    }
                }

                const item = manager.create(SalesOrderItem, {
                    shopId,
                    quantity,
                    unitPrice,
                    subtotal: lineSubtotal,
                    costPrice,
                    taxRate: Number(i.taxRate || 0),
                    taxAmount: Number(i.taxAmount || 0),
                    ...(product ? { product } : {}),
                });
                items.push(item);
            }

            const discountAmount = Number(dto.discountAmount || 0);
            const taxAmount = Number(dto.taxAmount || 0);
            const totalAmount = subtotal - discountAmount + taxAmount;
            const paidAmount = Number(dto.paidAmount || 0);
            const unpaidAmount = Math.max(totalAmount - paidAmount, 0);

            if (customer && Number(customer.creditLimit || 0) > 0) {
                const existingDebtRaw = await manager.createQueryBuilder(Receivable, 'r')
                    .select('COALESCE(SUM(r.amount - r.paid_amount), 0)', 'remainingDebt')
                    .where('r.customer_id = :customerId AND r.shop_id = :shopId', { customerId: customer.id, shopId })
                    .andWhere("r.status != 'PAID'")
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
                status: dto.status || 'PENDING',
                subtotal,
                discountAmount,
                taxAmount,
                totalAmount,
                totalCogs,
                paidAmount,
                paymentMethod: dto.paymentMethod || 'CASH',
                notes: dto.notes,
                invoiceNumber: dto.invoiceNumber,
                ...(customer ? { customer } : {}),
                items,
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
                    method: dto.paymentMethod || 'CASH',
                    referenceCode: dto.qrPaymentRef,
                    notes: 'Thanh toán khi tạo đơn hàng'
                }));

                await this.financeService.createCashTransaction(shopId, {
                    amount: paidAmount,
                    type: 'INCOME',
                    category: 'SALES',
                    paymentMethod: dto.paymentMethod || 'CASH',
                    referenceType: 'SALES_ORDER',
                    referenceId: savedOrder.id,
                    referenceCode: savedOrder.orderCode,
                    description: `Thanh toán cho đơn hàng ${savedOrder.orderCode}`,
                    transactionDate: savedOrder.orderDate,
                    status: 'COMPLETED'
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

            // Doanh thu: Có TK 511
            journalLines.push({ accountCode: '511', amount: totalAmount, entryType: 'CREDIT' });

            // Tiền mặt thu được: Nợ TK 111
            if (paidAmount > 0) {
                journalLines.push({ accountCode: '111', amount: paidAmount, entryType: 'DEBIT' });
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

    async cancel(shopId: number, id: number) {
        const queryRunner = AppDataSource.createQueryRunner();
        await queryRunner.connect();
        await queryRunner.startTransaction();

        try {
            const manager = queryRunner.manager;
            const order = await manager.findOne(SalesOrder, { where: { id, shopId } });
            if (!order) throw new Error('Order not found');
            
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
                        customer.balance = Number(customer.balance || 0) - unpaidAmount;
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
        // Only allow updating non-financial fields after creation
        const allowedFields: (keyof SalesOrder)[] = ['status', 'notes', 'invoiceNumber', 'paymentMethod'];
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
            const amount = Number(dto.amount || 0);
            if (amount <= 0) throw new Error('Validation: Payment amount must be greater than 0');
            const currentPaid = Number(order.paidAmount || 0);
            const totalAmount = Number(order.totalAmount || 0);
            if (currentPaid + amount > totalAmount) {
                throw new Error('Validation: Payment amount exceeds remaining order balance');
            }
            const payment = await manager.save(SalesOrderPayment, manager.create(SalesOrderPayment, { ...dto, shopId, order }));
            order.paidAmount = currentPaid + amount;
            order.status = (Number(order.paidAmount) >= totalAmount) ? 'DELIVERED' : 'PENDING';
            await manager.save(SalesOrder, order);

            await this.financeService.createCashTransaction(shopId, {
                amount,
                type: 'INCOME',
                category: 'SALES',
                paymentMethod: (dto as any).method || 'CASH',
                referenceType: 'SALES_ORDER',
                referenceId: order.id,
                referenceCode: order.orderCode,
                description: `Thanh toán thêm cho đơn hàng ${order.orderCode}`,
                transactionDate: new Date(),
                status: 'COMPLETED'
            } as any, manager);

            // === Journal Ledger: Thu nợ khách hàng (Nợ TK 111 / Có TK 131) ===
            await this.postingService.postJournal(
                shopId,
                'DEBT_COLLECTION',
                order.id,
                `Thu nợ khách hàng - Đơn ${order.orderCode}`,
                [
                    { accountCode: '111', amount, entryType: 'DEBIT' },
                    { accountCode: '131', amount, entryType: 'CREDIT' },
                ],
                manager
            );

            // Cập nhật Receivable nếu tồn tại
            const receivable = await manager.findOne(Receivable, {
                where: { shopId, orderId } as any,
            });
            if (receivable && receivable.status !== 'PAID' && receivable.status !== 'CANCELLED') {
                receivable.paidAmount = Number(receivable.paidAmount || 0) + amount;
                if (Number(receivable.paidAmount) >= Number(receivable.amount)) {
                    receivable.status = 'PAID';
                }
                await manager.save(Receivable, receivable);

                // Giảm số dư nợ khách hàng
                const customer = await manager.findOne(Customer, {
                    where: { id: (receivable as any).customerId || (receivable as any).customer?.id, shopId }
                });
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
            const order = await manager.findOne(SalesOrder, { where: { id: orderId, shopId } });
            if (!order) throw new Error('Order not found');
            if (order.status === 'CANCELLED') throw new Error('Cannot return a cancelled order');

            const returnDate = dto.returnDate ? new Date(dto.returnDate) : new Date();

            const rawItems: any[] = Array.isArray(dto.items) ? dto.items : [];
            let refundAmount = Number(dto.refundAmount || 0);

            if (!refundAmount && rawItems.length) {
                refundAmount = rawItems.reduce((sum: number, i: any) => sum + Number(i.subtotal || (Number(i.quantity || 0) * Number(i.unitPrice || 0))), 0);
            }

            const entity = manager.create(SalesReturn, {
                shopId,
                returnCode: dto.returnCode || 'RT' + Date.now().toString().slice(-6),
                order,
                returnDate,
                reason: dto.reason || '',
                refundAmount,
                refundMethod: dto.refundMethod || 'CASH',
                status: dto.status || 'PENDING',
                notes: dto.notes,
            } as any);

            if (rawItems.length) {
                (entity as any).items = [];
                for (const i of rawItems) {
                    const product = i.productId
                        ? await manager.findOne(Product, { where: { id: Number(i.productId), shopId } })
                        : null;

                    const returnItem = manager.create(SalesReturnItem, {
                        shopId,
                        ...(product ? { product } : {}),
                        quantity: Number(i.quantity || 0),
                        unitPrice: Number(i.unitPrice || 0),
                        subtotal: Number(i.subtotal || (Number(i.quantity || 0) * Number(i.unitPrice || 0))),
                        reason: i.reason,
                    });
                    (entity as any).items.push(returnItem);
                }
            }

            const savedReturn = await manager.save(SalesReturn, entity) as unknown as SalesReturn;

            order.returnStatus = 'RETURNED';
            await manager.save(SalesOrder, order);

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

            if (refundAmount > 0) {
                await this.financeService.createCashTransaction(shopId, {
                    amount: refundAmount,
                    type: 'EXPENSE',
                    category: 'REFUND',
                    paymentMethod: dto.refundMethod || 'CASH',
                    referenceType: 'SALES_RETURN',
                    referenceId: savedReturn.id,
                    referenceCode: savedReturn.returnCode,
                    description: `Hoàn tiền cho khách trả hàng ${savedReturn.returnCode} (Đơn ${order.orderCode})`,
                    transactionDate: savedReturn.returnDate,
                    status: 'COMPLETED'
                } as any, manager);

                // === Journal Ledger: Hoàn tiền trả hàng (Nợ TK 511 / Có TK 111) ===
                await this.postingService.postJournal(
                    shopId,
                    'SALES_RETURN',
                    savedReturn.id,
                    `Trả hàng - ${savedReturn.returnCode} (Đơn ${order.orderCode})`,
                    [
                        { accountCode: '511', amount: refundAmount, entryType: 'DEBIT' },
                        { accountCode: '111', amount: refundAmount, entryType: 'CREDIT' },
                    ],
                    manager
                );
            }

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
