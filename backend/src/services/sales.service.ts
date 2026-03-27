import { AppDataSource } from '../config/db.config';
import { SalesOrder, SalesOrderItem, SalesReturn, SalesOrderPayment } from '../sales/entities';
import { Customer } from '../customer/entities';
import { Product } from '../product/entities';
import { COGSService } from './cogs.service';

export class SalesService {
    private orderRepo = AppDataSource.getRepository(SalesOrder);
    private orderItemRepo = AppDataSource.getRepository(SalesOrderItem);
    private returnRepo = AppDataSource.getRepository(SalesReturn);
    private paymentRepo = AppDataSource.getRepository(SalesOrderPayment);
    private customerRepo = AppDataSource.getRepository(Customer);
    private productRepo = AppDataSource.getRepository(Product);
    private cogsService = new COGSService();

    async findAll(page = 1, limit = 20) {
        const [items, total] = await this.orderRepo.findAndCount({ skip: (page - 1) * limit, take: limit, order: { createdAt: 'DESC' } });
        return { items, total, page, limit, totalPages: Math.ceil(total / limit) };
    }
    
    async summary(from?: string, to?: string) {
        const fromDate = from ? new Date(from) : new Date(new Date().getFullYear(), new Date().getMonth(), 1);
        const toDate = to ? new Date(to) : new Date();
        toDate.setHours(23, 59, 59, 999);

        const result = await this.orderRepo.createQueryBuilder('o')
            .select('COALESCE(SUM(o.total_amount), 0)', 'totalRevenue')
            .addSelect('COALESCE(SUM(o.total_cogs), 0)', 'totalCogs')
            .addSelect('COUNT(o.id)', 'orderCount')
            .where("o.order_date >= :fromDate AND o.order_date <= :toDate AND o.status != 'CANCELLED'", { fromDate, toDate })
            .getRawOne();

        return {
            totalRevenue: Number(result?.totalRevenue || 0),
            totalCogs: Number(result?.totalCogs || 0),
            grossProfit: Number(result?.totalRevenue || 0) - Number(result?.totalCogs || 0),
            orderCount: Number(result?.orderCount || 0),
        };
    }

    async findById(id: number) {
        const order = await this.orderRepo.findOne({ where: { id }, relations: ['items', 'payments'] });
        if (!order) throw new Error('Order not found');

        const returns = await this.returnRepo.find({
            where: { order: { id } as any } as any,
            relations: ['items'],
            order: { createdAt: 'DESC' } as any,
        });

        return { ...(order as any), returns };
    }

    async create(dto: any) {
        const orderDate = dto.orderDate ? new Date(dto.orderDate) : new Date();

        const customer = dto.customerId
            ? await this.customerRepo.findOne({ where: { id: Number(dto.customerId) } })
            : null;

        let subtotal = 0;
        let totalCogs = 0;
        const rawItems: any[] = Array.isArray(dto.items) ? dto.items : [];
        const allLotDeductions: { lotId: number; qty: number }[] = [];

        const items: SalesOrderItem[] = [];
        for (const i of rawItems) {
            const quantity = Number(i.quantity || 0);
            const unitPrice = Number(i.unitPrice || 0);
            const lineSubtotal = quantity * unitPrice;
            subtotal += lineSubtotal;

            const product = i.productId
                ? await this.productRepo.findOne({ where: { id: Number(i.productId) } })
                : null;

            // Tính giá vốn cho item này
            let costPrice = 0;
            if (product && quantity > 0) {
                try {
                    const cogsResult = await this.cogsService.calculateCOGS(product.id, quantity);
                    costPrice = cogsResult.unitCost;
                    totalCogs += cogsResult.totalCost;
                    allLotDeductions.push(...cogsResult.lotDeductions);
                } catch {
                    costPrice = Number(product.costPrice || 0);
                    totalCogs += costPrice * quantity;
                }
            }

            const item = (this.orderItemRepo as any).create({
                quantity,
                unitPrice,
                subtotal: lineSubtotal,
                costPrice,
                taxRate: Number(i.taxRate || 0),
                taxAmount: Number(i.taxAmount || 0),
                ...(product ? { product } : {}),
            }) as SalesOrderItem;
            items.push(item as SalesOrderItem);
        }

        const discountAmount = Number(dto.discountAmount || 0);
        const taxAmount = Number(dto.taxAmount || 0);
        const totalAmount = subtotal - discountAmount + taxAmount;

        const order = this.orderRepo.create({
            orderCode: dto.orderCode || 'SO' + Date.now().toString().slice(-6),
            orderDate,
            status: dto.status || 'PENDING',
            subtotal,
            discountAmount,
            taxAmount,
            totalAmount,
            totalCogs,
            paidAmount: Number(dto.paidAmount || 0),
            paymentMethod: dto.paymentMethod || 'CASH',
            notes: dto.notes,
            invoiceNumber: dto.invoiceNumber,
            ...(customer ? { customer } : {}),
            items,
        } as any);

        const savedOrder = await this.orderRepo.save(order);

        // Commit: trừ tồn kho các lô
        if (allLotDeductions.length > 0) {
            await this.cogsService.commitLotDeductions(allLotDeductions);
        }

        return savedOrder;
    }

    async cancel(id: number) {
        const order = await this.findById(id);
        order.status = 'CANCELLED';
        return this.orderRepo.save(order);
    }

    async addPayment(orderId: number, dto: Partial<SalesOrderPayment>) {
        const order = await this.findById(orderId);
        const payment = await this.paymentRepo.save(this.paymentRepo.create({ ...dto, order }));
        order.paidAmount = Number(order.paidAmount || 0) + Number(dto.amount);
        order.status = (order.paidAmount >= order.totalAmount) ? 'DELIVERED' : 'PENDING';
        await this.orderRepo.save(order);
        return payment;
    }

    async createReturn(orderId: number, dto: any) {
        // Use base order entity (not the aggregated object returned by findById).
        const order = await this.orderRepo.findOne({ where: { id: orderId } });
        if (!order) throw new Error('Order not found');

        // return_date is NOT NULL in schema → always set.
        const returnDate = dto.returnDate ? new Date(dto.returnDate) : new Date();

        const rawItems: any[] = Array.isArray(dto.items) ? dto.items : [];
        let refundAmount = Number(dto.refundAmount || 0);

        // If items are provided and refundAmount isn't, derive it.
        if (!refundAmount && rawItems.length) {
            refundAmount = rawItems.reduce((sum, i) => sum + Number(i.subtotal || (Number(i.quantity || 0) * Number(i.unitPrice || 0))), 0);
        }

        const entity = this.returnRepo.create({
            returnCode: dto.returnCode || 'RT' + Date.now().toString().slice(-6),
            order,
            returnDate,
            reason: dto.reason || '',
            refundAmount,
            refundMethod: dto.refundMethod || 'CASH',
            status: dto.status || 'PENDING',
            notes: dto.notes,
            // items handled below (needs Product lookup)
        } as any);

        if (rawItems.length) {
            (entity as any).items = [];
            for (const i of rawItems) {
                const product = i.productId
                    ? await this.productRepo.findOne({ where: { id: Number(i.productId) } })
                    : null;

                (entity as any).items.push({
                    ...(product ? { product } : {}),
                    quantity: Number(i.quantity || 0),
                    unitPrice: Number(i.unitPrice || 0),
                    subtotal: Number(i.subtotal || (Number(i.quantity || 0) * Number(i.unitPrice || 0))),
                    reason: i.reason,
                });
            }
        }

        return this.returnRepo.save(entity);
    }
}
