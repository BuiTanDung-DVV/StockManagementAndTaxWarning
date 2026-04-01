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
Object.defineProperty(exports, "__esModule", { value: true });
exports.SalesReturnItem = exports.SalesReturn = exports.SalesOrderPayment = exports.SalesOrderItem = exports.SalesOrder = void 0;
const typeorm_1 = require("typeorm");
const entities_1 = require("../customer/entities");
const entities_2 = require("../product/entities");
let SalesOrder = class SalesOrder {
};
exports.SalesOrder = SalesOrder;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)(),
    __metadata("design:type", Number)
], SalesOrder.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'order_code', unique: true, length: 20 }),
    __metadata("design:type", String)
], SalesOrder.prototype, "orderCode", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => entities_1.Customer, { nullable: true }),
    (0, typeorm_1.JoinColumn)({ name: 'customer_id' }),
    __metadata("design:type", entities_1.Customer)
], SalesOrder.prototype, "customer", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'order_date' }),
    __metadata("design:type", Date)
], SalesOrder.prototype, "orderDate", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 20, default: 'PENDING' }),
    __metadata("design:type", String)
], SalesOrder.prototype, "status", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'decimal', precision: 18, scale: 2, default: 0 }),
    __metadata("design:type", Number)
], SalesOrder.prototype, "subtotal", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'discount_amount', type: 'decimal', precision: 18, scale: 2, default: 0 }),
    __metadata("design:type", Number)
], SalesOrder.prototype, "discountAmount", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'tax_amount', type: 'decimal', precision: 18, scale: 2, default: 0 }),
    __metadata("design:type", Number)
], SalesOrder.prototype, "taxAmount", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'total_amount', type: 'decimal', precision: 18, scale: 2, default: 0 }),
    __metadata("design:type", Number)
], SalesOrder.prototype, "totalAmount", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'total_cogs', type: 'decimal', precision: 18, scale: 2, default: 0 }),
    __metadata("design:type", Number)
], SalesOrder.prototype, "totalCogs", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'paid_amount', type: 'decimal', precision: 18, scale: 2, default: 0 }),
    __metadata("design:type", Number)
], SalesOrder.prototype, "paidAmount", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'payment_method', length: 10, default: 'CASH' }),
    __metadata("design:type", String)
], SalesOrder.prototype, "paymentMethod", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 500, nullable: true }),
    __metadata("design:type", String)
], SalesOrder.prototype, "notes", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'return_status', length: 20, default: 'NONE' }),
    __metadata("design:type", String)
], SalesOrder.prototype, "returnStatus", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'hold_until', nullable: true }),
    __metadata("design:type", Date)
], SalesOrder.prototype, "holdUntil", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'qr_payment_ref', length: 100, nullable: true }),
    __metadata("design:type", String)
], SalesOrder.prototype, "qrPaymentRef", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'invoice_number', length: 50, nullable: true }),
    __metadata("design:type", String)
], SalesOrder.prototype, "invoiceNumber", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'created_by', nullable: true }),
    __metadata("design:type", Number)
], SalesOrder.prototype, "createdBy", void 0);
__decorate([
    (0, typeorm_1.OneToMany)(() => SalesOrderItem, (i) => i.order, { cascade: true }),
    __metadata("design:type", Array)
], SalesOrder.prototype, "items", void 0);
__decorate([
    (0, typeorm_1.OneToMany)(() => SalesOrderPayment, (p) => p.order, { cascade: true }),
    __metadata("design:type", Array)
], SalesOrder.prototype, "payments", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'created_at' }),
    __metadata("design:type", Date)
], SalesOrder.prototype, "createdAt", void 0);
__decorate([
    (0, typeorm_1.UpdateDateColumn)({ name: 'updated_at' }),
    __metadata("design:type", Date)
], SalesOrder.prototype, "updatedAt", void 0);
exports.SalesOrder = SalesOrder = __decorate([
    (0, typeorm_1.Entity)('sales_orders')
], SalesOrder);
let SalesOrderItem = class SalesOrderItem {
};
exports.SalesOrderItem = SalesOrderItem;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)(),
    __metadata("design:type", Number)
], SalesOrderItem.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => SalesOrder, (o) => o.items),
    (0, typeorm_1.JoinColumn)({ name: 'order_id' }),
    __metadata("design:type", SalesOrder)
], SalesOrderItem.prototype, "order", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => entities_2.Product),
    (0, typeorm_1.JoinColumn)({ name: 'product_id' }),
    __metadata("design:type", entities_2.Product)
], SalesOrderItem.prototype, "product", void 0);
__decorate([
    (0, typeorm_1.Column)(),
    __metadata("design:type", Number)
], SalesOrderItem.prototype, "quantity", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'unit_price', type: 'decimal', precision: 18, scale: 2 }),
    __metadata("design:type", Number)
], SalesOrderItem.prototype, "unitPrice", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'decimal', precision: 18, scale: 2 }),
    __metadata("design:type", Number)
], SalesOrderItem.prototype, "subtotal", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'cost_price', type: 'decimal', precision: 18, scale: 2, default: 0 }),
    __metadata("design:type", Number)
], SalesOrderItem.prototype, "costPrice", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'tax_rate', type: 'decimal', precision: 5, scale: 2, default: 0 }),
    __metadata("design:type", Number)
], SalesOrderItem.prototype, "taxRate", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'tax_amount', type: 'decimal', precision: 18, scale: 2, default: 0 }),
    __metadata("design:type", Number)
], SalesOrderItem.prototype, "taxAmount", void 0);
exports.SalesOrderItem = SalesOrderItem = __decorate([
    (0, typeorm_1.Entity)('sales_order_items')
], SalesOrderItem);
let SalesOrderPayment = class SalesOrderPayment {
};
exports.SalesOrderPayment = SalesOrderPayment;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)(),
    __metadata("design:type", Number)
], SalesOrderPayment.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => SalesOrder, (o) => o.payments),
    (0, typeorm_1.JoinColumn)({ name: 'order_id' }),
    __metadata("design:type", SalesOrder)
], SalesOrderPayment.prototype, "order", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'decimal', precision: 18, scale: 2 }),
    __metadata("design:type", Number)
], SalesOrderPayment.prototype, "amount", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 20, default: 'CASH' }),
    __metadata("design:type", String)
], SalesOrderPayment.prototype, "method", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'reference_code', length: 100, nullable: true }),
    __metadata("design:type", String)
], SalesOrderPayment.prototype, "referenceCode", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 200, nullable: true }),
    __metadata("design:type", String)
], SalesOrderPayment.prototype, "notes", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'paid_at' }),
    __metadata("design:type", Date)
], SalesOrderPayment.prototype, "paidAt", void 0);
exports.SalesOrderPayment = SalesOrderPayment = __decorate([
    (0, typeorm_1.Entity)('sales_order_payments')
], SalesOrderPayment);
let SalesReturn = class SalesReturn {
};
exports.SalesReturn = SalesReturn;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)(),
    __metadata("design:type", Number)
], SalesReturn.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'return_code', unique: true, length: 20 }),
    __metadata("design:type", String)
], SalesReturn.prototype, "returnCode", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => SalesOrder),
    (0, typeorm_1.JoinColumn)({ name: 'order_id' }),
    __metadata("design:type", SalesOrder)
], SalesReturn.prototype, "order", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'return_date' }),
    __metadata("design:type", Date)
], SalesReturn.prototype, "returnDate", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 500 }),
    __metadata("design:type", String)
], SalesReturn.prototype, "reason", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'refund_amount', type: 'decimal', precision: 18, scale: 2, default: 0 }),
    __metadata("design:type", Number)
], SalesReturn.prototype, "refundAmount", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'refund_method', length: 20, default: 'CASH' }),
    __metadata("design:type", String)
], SalesReturn.prototype, "refundMethod", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 20, default: 'PENDING' }),
    __metadata("design:type", String)
], SalesReturn.prototype, "status", void 0);
__decorate([
    (0, typeorm_1.OneToMany)(() => SalesReturnItem, (i) => i.salesReturn, { cascade: true }),
    __metadata("design:type", Array)
], SalesReturn.prototype, "items", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'processed_by', nullable: true }),
    __metadata("design:type", Number)
], SalesReturn.prototype, "processedBy", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 500, nullable: true }),
    __metadata("design:type", String)
], SalesReturn.prototype, "notes", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'created_at' }),
    __metadata("design:type", Date)
], SalesReturn.prototype, "createdAt", void 0);
exports.SalesReturn = SalesReturn = __decorate([
    (0, typeorm_1.Entity)('sales_returns')
], SalesReturn);
let SalesReturnItem = class SalesReturnItem {
};
exports.SalesReturnItem = SalesReturnItem;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)(),
    __metadata("design:type", Number)
], SalesReturnItem.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => SalesReturn, (r) => r.items),
    (0, typeorm_1.JoinColumn)({ name: 'return_id' }),
    __metadata("design:type", SalesReturn)
], SalesReturnItem.prototype, "salesReturn", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => entities_2.Product),
    (0, typeorm_1.JoinColumn)({ name: 'product_id' }),
    __metadata("design:type", entities_2.Product)
], SalesReturnItem.prototype, "product", void 0);
__decorate([
    (0, typeorm_1.Column)(),
    __metadata("design:type", Number)
], SalesReturnItem.prototype, "quantity", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'unit_price', type: 'decimal', precision: 18, scale: 2 }),
    __metadata("design:type", Number)
], SalesReturnItem.prototype, "unitPrice", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'decimal', precision: 18, scale: 2 }),
    __metadata("design:type", Number)
], SalesReturnItem.prototype, "subtotal", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 200, nullable: true }),
    __metadata("design:type", String)
], SalesReturnItem.prototype, "reason", void 0);
exports.SalesReturnItem = SalesReturnItem = __decorate([
    (0, typeorm_1.Entity)('sales_return_items')
], SalesReturnItem);
//# sourceMappingURL=entities.js.map