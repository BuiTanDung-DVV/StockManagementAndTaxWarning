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
exports.StockTakeItem = exports.StockTake = exports.PurchaseOrderItem = exports.PurchaseOrder = exports.InventoryMovement = exports.InventoryStock = exports.Warehouse = void 0;
const typeorm_1 = require("typeorm");
const entities_1 = require("../product/entities");
let Warehouse = class Warehouse {
};
exports.Warehouse = Warehouse;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)(),
    __metadata("design:type", Number)
], Warehouse.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ unique: true, length: 100 }),
    __metadata("design:type", String)
], Warehouse.prototype, "name", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 500, nullable: true }),
    __metadata("design:type", String)
], Warehouse.prototype, "address", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'is_active', default: true }),
    __metadata("design:type", Boolean)
], Warehouse.prototype, "isActive", void 0);
exports.Warehouse = Warehouse = __decorate([
    (0, typeorm_1.Entity)('warehouses')
], Warehouse);
let InventoryStock = class InventoryStock {
};
exports.InventoryStock = InventoryStock;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)(),
    __metadata("design:type", Number)
], InventoryStock.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'product_id' }),
    __metadata("design:type", Number)
], InventoryStock.prototype, "productId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => entities_1.Product),
    (0, typeorm_1.JoinColumn)({ name: 'product_id' }),
    __metadata("design:type", entities_1.Product)
], InventoryStock.prototype, "product", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'warehouse_id' }),
    __metadata("design:type", Number)
], InventoryStock.prototype, "warehouseId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => Warehouse),
    (0, typeorm_1.JoinColumn)({ name: 'warehouse_id' }),
    __metadata("design:type", Warehouse)
], InventoryStock.prototype, "warehouse", void 0);
__decorate([
    (0, typeorm_1.Column)({ default: 0 }),
    __metadata("design:type", Number)
], InventoryStock.prototype, "quantity", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'updated_at' }),
    __metadata("design:type", Date)
], InventoryStock.prototype, "updatedAt", void 0);
exports.InventoryStock = InventoryStock = __decorate([
    (0, typeorm_1.Entity)('inventory_stocks')
], InventoryStock);
let InventoryMovement = class InventoryMovement {
};
exports.InventoryMovement = InventoryMovement;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)(),
    __metadata("design:type", Number)
], InventoryMovement.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'product_id' }),
    __metadata("design:type", Number)
], InventoryMovement.prototype, "productId", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'warehouse_id' }),
    __metadata("design:type", Number)
], InventoryMovement.prototype, "warehouseId", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'movement_type', length: 20 }),
    __metadata("design:type", String)
], InventoryMovement.prototype, "movementType", void 0);
__decorate([
    (0, typeorm_1.Column)(),
    __metadata("design:type", Number)
], InventoryMovement.prototype, "quantity", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'reference_type', length: 20, nullable: true }),
    __metadata("design:type", String)
], InventoryMovement.prototype, "referenceType", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'reference_id', nullable: true }),
    __metadata("design:type", Number)
], InventoryMovement.prototype, "referenceId", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 500, nullable: true }),
    __metadata("design:type", String)
], InventoryMovement.prototype, "notes", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'created_by', nullable: true }),
    __metadata("design:type", Number)
], InventoryMovement.prototype, "createdBy", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'created_at' }),
    __metadata("design:type", Date)
], InventoryMovement.prototype, "createdAt", void 0);
exports.InventoryMovement = InventoryMovement = __decorate([
    (0, typeorm_1.Entity)('inventory_movements')
], InventoryMovement);
let PurchaseOrder = class PurchaseOrder {
};
exports.PurchaseOrder = PurchaseOrder;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)(),
    __metadata("design:type", Number)
], PurchaseOrder.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'order_code', unique: true, length: 20 }),
    __metadata("design:type", String)
], PurchaseOrder.prototype, "orderCode", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'supplier_id' }),
    __metadata("design:type", Number)
], PurchaseOrder.prototype, "supplierId", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'warehouse_id', nullable: true }),
    __metadata("design:type", Number)
], PurchaseOrder.prototype, "warehouseId", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'order_date' }),
    __metadata("design:type", Date)
], PurchaseOrder.prototype, "orderDate", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'payment_due_date', type: 'date', nullable: true }),
    __metadata("design:type", Date)
], PurchaseOrder.prototype, "paymentDueDate", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'invoice_number', length: 50, nullable: true }),
    __metadata("design:type", String)
], PurchaseOrder.prototype, "invoiceNumber", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 20, default: 'PENDING' }),
    __metadata("design:type", String)
], PurchaseOrder.prototype, "status", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'decimal', precision: 18, scale: 2, default: 0 }),
    __metadata("design:type", Number)
], PurchaseOrder.prototype, "subtotal", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'discount_amount', type: 'decimal', precision: 18, scale: 2, default: 0 }),
    __metadata("design:type", Number)
], PurchaseOrder.prototype, "discountAmount", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'tax_amount', type: 'decimal', precision: 18, scale: 2, default: 0 }),
    __metadata("design:type", Number)
], PurchaseOrder.prototype, "taxAmount", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'total_amount', type: 'decimal', precision: 18, scale: 2, default: 0 }),
    __metadata("design:type", Number)
], PurchaseOrder.prototype, "totalAmount", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'paid_amount', type: 'decimal', precision: 18, scale: 2, default: 0 }),
    __metadata("design:type", Number)
], PurchaseOrder.prototype, "paidAmount", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 500, nullable: true }),
    __metadata("design:type", String)
], PurchaseOrder.prototype, "notes", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'created_by', nullable: true }),
    __metadata("design:type", Number)
], PurchaseOrder.prototype, "createdBy", void 0);
__decorate([
    (0, typeorm_1.OneToMany)(() => PurchaseOrderItem, (i) => i.order, { cascade: true }),
    __metadata("design:type", Array)
], PurchaseOrder.prototype, "items", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'created_at' }),
    __metadata("design:type", Date)
], PurchaseOrder.prototype, "createdAt", void 0);
exports.PurchaseOrder = PurchaseOrder = __decorate([
    (0, typeorm_1.Entity)('purchase_orders')
], PurchaseOrder);
let PurchaseOrderItem = class PurchaseOrderItem {
};
exports.PurchaseOrderItem = PurchaseOrderItem;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)(),
    __metadata("design:type", Number)
], PurchaseOrderItem.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => PurchaseOrder, (o) => o.items),
    (0, typeorm_1.JoinColumn)({ name: 'order_id' }),
    __metadata("design:type", PurchaseOrder)
], PurchaseOrderItem.prototype, "order", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => entities_1.Product),
    (0, typeorm_1.JoinColumn)({ name: 'product_id' }),
    __metadata("design:type", entities_1.Product)
], PurchaseOrderItem.prototype, "product", void 0);
__decorate([
    (0, typeorm_1.Column)(),
    __metadata("design:type", Number)
], PurchaseOrderItem.prototype, "quantity", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'unit_price', type: 'decimal', precision: 18, scale: 2 }),
    __metadata("design:type", Number)
], PurchaseOrderItem.prototype, "unitPrice", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'decimal', precision: 18, scale: 2 }),
    __metadata("design:type", Number)
], PurchaseOrderItem.prototype, "subtotal", void 0);
exports.PurchaseOrderItem = PurchaseOrderItem = __decorate([
    (0, typeorm_1.Entity)('purchase_order_items')
], PurchaseOrderItem);
let StockTake = class StockTake {
};
exports.StockTake = StockTake;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)(),
    __metadata("design:type", Number)
], StockTake.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'stock_take_code', unique: true, length: 20 }),
    __metadata("design:type", String)
], StockTake.prototype, "stockTakeCode", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'stock_take_date', type: 'date' }),
    __metadata("design:type", Date)
], StockTake.prototype, "stockTakeDate", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 20, default: 'DRAFT' }),
    __metadata("design:type", String)
], StockTake.prototype, "status", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 500, nullable: true }),
    __metadata("design:type", String)
], StockTake.prototype, "notes", void 0);
__decorate([
    (0, typeorm_1.OneToMany)(() => StockTakeItem, (i) => i.stockTake, { cascade: true }),
    __metadata("design:type", Array)
], StockTake.prototype, "items", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'created_by', nullable: true }),
    __metadata("design:type", Number)
], StockTake.prototype, "createdBy", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'approved_by', nullable: true }),
    __metadata("design:type", Number)
], StockTake.prototype, "approvedBy", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'completed_at', nullable: true }),
    __metadata("design:type", Date)
], StockTake.prototype, "completedAt", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'created_at' }),
    __metadata("design:type", Date)
], StockTake.prototype, "createdAt", void 0);
exports.StockTake = StockTake = __decorate([
    (0, typeorm_1.Entity)('stock_takes')
], StockTake);
let StockTakeItem = class StockTakeItem {
};
exports.StockTakeItem = StockTakeItem;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)(),
    __metadata("design:type", Number)
], StockTakeItem.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => StockTake, (s) => s.items),
    (0, typeorm_1.JoinColumn)({ name: 'stock_take_id' }),
    __metadata("design:type", StockTake)
], StockTakeItem.prototype, "stockTake", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => entities_1.Product),
    (0, typeorm_1.JoinColumn)({ name: 'product_id' }),
    __metadata("design:type", entities_1.Product)
], StockTakeItem.prototype, "product", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'system_qty' }),
    __metadata("design:type", Number)
], StockTakeItem.prototype, "systemQty", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'actual_qty' }),
    __metadata("design:type", Number)
], StockTakeItem.prototype, "actualQty", void 0);
__decorate([
    (0, typeorm_1.Column)({ default: 0 }),
    __metadata("design:type", Number)
], StockTakeItem.prototype, "difference", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 200, nullable: true }),
    __metadata("design:type", String)
], StockTakeItem.prototype, "notes", void 0);
exports.StockTakeItem = StockTakeItem = __decorate([
    (0, typeorm_1.Entity)('stock_take_items')
], StockTakeItem);
//# sourceMappingURL=entities.js.map