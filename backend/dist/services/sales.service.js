"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.SalesService = void 0;
const db_config_1 = require("../config/db.config");
const entities_1 = require("../sales/entities");
const entities_2 = require("../customer/entities");
const entities_3 = require("../product/entities");
class SalesService {
    constructor() {
        this.orderRepo = db_config_1.AppDataSource.getRepository(entities_1.SalesOrder);
        this.orderItemRepo = db_config_1.AppDataSource.getRepository(entities_1.SalesOrderItem);
        this.returnRepo = db_config_1.AppDataSource.getRepository(entities_1.SalesReturn);
        this.paymentRepo = db_config_1.AppDataSource.getRepository(entities_1.SalesOrderPayment);
        this.customerRepo = db_config_1.AppDataSource.getRepository(entities_2.Customer);
        this.productRepo = db_config_1.AppDataSource.getRepository(entities_3.Product);
    }
    async findAll(page = 1, limit = 20) {
        const [items, total] = await this.orderRepo.findAndCount({ skip: (page - 1) * limit, take: limit, order: { createdAt: 'DESC' } });
        return { items, total, page, limit, totalPages: Math.ceil(total / limit) };
    }
    async summary(from, to) {
        return { totalRevenue: 0, orderCount: 0 };
    }
    async findById(id) {
        const order = await this.orderRepo.findOne({ where: { id }, relations: ['items', 'payments'] });
        if (!order)
            throw new Error('Order not found');
        const returns = await this.returnRepo.find({
            where: { order: { id } },
            relations: ['items'],
            order: { createdAt: 'DESC' },
        });
        return { ...order, returns };
    }
    async create(dto) {
        const orderDate = dto.orderDate ? new Date(dto.orderDate) : new Date();
        const customer = dto.customerId
            ? await this.customerRepo.findOne({ where: { id: Number(dto.customerId) } })
            : null;
        let subtotal = 0;
        const rawItems = Array.isArray(dto.items) ? dto.items : [];
        const items = [];
        for (const i of rawItems) {
            const quantity = Number(i.quantity || 0);
            const unitPrice = Number(i.unitPrice || 0);
            const lineSubtotal = quantity * unitPrice;
            subtotal += lineSubtotal;
            const product = i.productId
                ? await this.productRepo.findOne({ where: { id: Number(i.productId) } })
                : null;
            const item = this.orderItemRepo.create({
                quantity,
                unitPrice,
                subtotal: lineSubtotal,
                taxRate: Number(i.taxRate || 0),
                taxAmount: Number(i.taxAmount || 0),
                ...(product ? { product } : {}),
            });
            items.push(item);
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
            paidAmount: Number(dto.paidAmount || 0),
            paymentMethod: dto.paymentMethod || 'CASH',
            notes: dto.notes,
            invoiceNumber: dto.invoiceNumber,
            ...(customer ? { customer } : {}),
            items,
        });
        return this.orderRepo.save(order);
    }
    async cancel(id) {
        const order = await this.findById(id);
        order.status = 'CANCELLED';
        return this.orderRepo.save(order);
    }
    async addPayment(orderId, dto) {
        const order = await this.findById(orderId);
        const payment = await this.paymentRepo.save(this.paymentRepo.create({ ...dto, order }));
        order.paidAmount = Number(order.paidAmount || 0) + Number(dto.amount);
        order.status = (order.paidAmount >= order.totalAmount) ? 'DELIVERED' : 'PENDING';
        await this.orderRepo.save(order);
        return payment;
    }
    async createReturn(orderId, dto) {
        const order = await this.orderRepo.findOne({ where: { id: orderId } });
        if (!order)
            throw new Error('Order not found');
        const returnDate = dto.returnDate ? new Date(dto.returnDate) : new Date();
        const rawItems = Array.isArray(dto.items) ? dto.items : [];
        let refundAmount = Number(dto.refundAmount || 0);
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
        });
        if (rawItems.length) {
            entity.items = [];
            for (const i of rawItems) {
                const product = i.productId
                    ? await this.productRepo.findOne({ where: { id: Number(i.productId) } })
                    : null;
                entity.items.push({
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
exports.SalesService = SalesService;
//# sourceMappingURL=sales.service.js.map