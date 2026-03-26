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
exports.SalesService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const entities_1 = require("./entities");
let SalesService = class SalesService {
    constructor(orderRepo, itemRepo, paymentRepo, returnRepo, returnItemRepo) {
        this.orderRepo = orderRepo;
        this.itemRepo = itemRepo;
        this.paymentRepo = paymentRepo;
        this.returnRepo = returnRepo;
        this.returnItemRepo = returnItemRepo;
    }
    async findAll(page = 1, limit = 20, status) {
        const where = status ? { status } : {};
        const [items, total] = await this.orderRepo.findAndCount({
            where, relations: ['customer', 'items', 'items.product', 'payments', 'createdBy'],
            skip: (page - 1) * limit, take: limit, order: { createdAt: 'DESC' },
        });
        return { items, total, page, limit, totalPages: Math.ceil(total / limit) };
    }
    async findById(id) {
        const order = await this.orderRepo.findOne({
            where: { id }, relations: ['customer', 'items', 'items.product', 'payments', 'createdBy'],
        });
        if (!order)
            throw new common_1.NotFoundException('Order not found');
        return order;
    }
    async createOrder(dto) {
        const orderCode = 'DH' + Date.now().toString().slice(-8);
        let subtotal = 0;
        const orderItems = dto.items.map(i => {
            const sub = i.quantity * i.unitPrice;
            subtotal += sub;
            return { product: { id: i.productId }, quantity: i.quantity, unitPrice: i.unitPrice, subtotal: sub };
        });
        const order = this.orderRepo.create({
            orderCode, orderDate: new Date(), status: 'CONFIRMED', subtotal, totalAmount: subtotal,
            paymentMethod: dto.paymentMethod || 'CASH', notes: dto.notes,
            customer: dto.customerId ? { id: dto.customerId } : undefined,
            items: orderItems,
        });
        return this.orderRepo.save(order);
    }
    async cancelOrder(id) {
        const order = await this.findById(id);
        order.status = 'CANCELLED';
        return this.orderRepo.save(order);
    }
    async addPayment(orderId, dto) {
        const order = await this.findById(orderId);
        const payment = this.paymentRepo.create({ order, ...dto });
        await this.paymentRepo.save(payment);
        order.paidAmount = Number(order.paidAmount) + dto.amount;
        await this.orderRepo.save(order);
        return payment;
    }
    async createReturn(orderId, dto) {
        const order = await this.findById(orderId);
        const returnCode = 'TH' + Date.now().toString().slice(-8);
        let refundAmount = 0;
        const returnItems = dto.items.map(i => {
            const sub = i.quantity * i.unitPrice;
            refundAmount += sub;
            return this.returnItemRepo.create({ product: { id: i.productId }, quantity: i.quantity, unitPrice: i.unitPrice, subtotal: sub, reason: i.reason });
        });
        const salesReturn = this.returnRepo.create({
            returnCode, order, returnDate: new Date(), reason: dto.reason, refundAmount,
            status: 'APPROVED', items: returnItems,
        });
        await this.returnRepo.save(salesReturn);
        order.returnStatus = refundAmount >= Number(order.totalAmount) ? 'FULL_RETURN' : 'PARTIAL_RETURN';
        await this.orderRepo.save(order);
        return salesReturn;
    }
    async getSalesSummary(from, to) {
        const result = await this.orderRepo.createQueryBuilder('o')
            .select('COUNT(o.id)', 'totalOrders')
            .addSelect('COALESCE(SUM(o.totalAmount), 0)', 'totalRevenue')
            .where('o.status != :cancelled', { cancelled: 'CANCELLED' })
            .andWhere('o.orderDate BETWEEN :from AND :to', { from, to })
            .getRawOne();
        return result;
    }
};
exports.SalesService = SalesService;
exports.SalesService = SalesService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(entities_1.SalesOrder)),
    __param(1, (0, typeorm_1.InjectRepository)(entities_1.SalesOrderItem)),
    __param(2, (0, typeorm_1.InjectRepository)(entities_1.SalesOrderPayment)),
    __param(3, (0, typeorm_1.InjectRepository)(entities_1.SalesReturn)),
    __param(4, (0, typeorm_1.InjectRepository)(entities_1.SalesReturnItem)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository])
], SalesService);
//# sourceMappingURL=sales.service.js.map