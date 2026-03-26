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
exports.ProductPriceHistory = exports.UnitConversion = exports.ProductBatch = exports.ProductCostItem = exports.CostType = exports.Product = exports.Category = void 0;
const typeorm_1 = require("typeorm");
let Category = class Category {
};
exports.Category = Category;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)(),
    __metadata("design:type", Number)
], Category.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ unique: true, length: 100 }),
    __metadata("design:type", String)
], Category.prototype, "name", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 500, nullable: true }),
    __metadata("design:type", String)
], Category.prototype, "description", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'is_active', default: true }),
    __metadata("design:type", Boolean)
], Category.prototype, "isActive", void 0);
__decorate([
    (0, typeorm_1.OneToMany)(() => Product, (p) => p.category),
    __metadata("design:type", Array)
], Category.prototype, "products", void 0);
exports.Category = Category = __decorate([
    (0, typeorm_1.Entity)('categories')
], Category);
let Product = class Product {
};
exports.Product = Product;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)(),
    __metadata("design:type", Number)
], Product.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ unique: true, length: 50 }),
    __metadata("design:type", String)
], Product.prototype, "sku", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 200 }),
    __metadata("design:type", String)
], Product.prototype, "name", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => Category, { nullable: true }),
    (0, typeorm_1.JoinColumn)({ name: 'category_id' }),
    __metadata("design:type", Category)
], Product.prototype, "category", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 20, default: 'Cái' }),
    __metadata("design:type", String)
], Product.prototype, "unit", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'cost_price', type: 'decimal', precision: 18, scale: 2, default: 0 }),
    __metadata("design:type", Number)
], Product.prototype, "costPrice", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'selling_price', type: 'decimal', precision: 18, scale: 2, default: 0 }),
    __metadata("design:type", Number)
], Product.prototype, "sellingPrice", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'wholesale_price', type: 'decimal', precision: 18, scale: 2, nullable: true }),
    __metadata("design:type", Number)
], Product.prototype, "wholesalePrice", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'wholesale_min_qty', nullable: true }),
    __metadata("design:type", Number)
], Product.prototype, "wholesaleMinQty", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'tax_rate', type: 'decimal', precision: 5, scale: 2, default: 0 }),
    __metadata("design:type", Number)
], Product.prototype, "taxRate", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'profit_margin', type: 'decimal', precision: 5, scale: 2, nullable: true }),
    __metadata("design:type", Number)
], Product.prototype, "profitMargin", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'supplier_discount', type: 'decimal', precision: 18, scale: 2, default: 0 }),
    __metadata("design:type", Number)
], Product.prototype, "supplierDiscount", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'promo_price', type: 'decimal', precision: 18, scale: 2, nullable: true }),
    __metadata("design:type", Number)
], Product.prototype, "promoPrice", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'promo_start', type: 'date', nullable: true }),
    __metadata("design:type", Date)
], Product.prototype, "promoStart", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'promo_end', type: 'date', nullable: true }),
    __metadata("design:type", Date)
], Product.prototype, "promoEnd", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'total_additional_cost', type: 'decimal', precision: 18, scale: 2, default: 0 }),
    __metadata("design:type", Number)
], Product.prototype, "totalAdditionalCost", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'suggested_price', type: 'decimal', precision: 18, scale: 2, nullable: true }),
    __metadata("design:type", Number)
], Product.prototype, "suggestedPrice", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'min_stock', default: 0 }),
    __metadata("design:type", Number)
], Product.prototype, "minStock", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'image_url', length: 500, nullable: true }),
    __metadata("design:type", String)
], Product.prototype, "imageUrl", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 50, nullable: true }),
    __metadata("design:type", String)
], Product.prototype, "barcode", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 1000, nullable: true }),
    __metadata("design:type", String)
], Product.prototype, "description", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'is_active', default: true }),
    __metadata("design:type", Boolean)
], Product.prototype, "isActive", void 0);
__decorate([
    (0, typeorm_1.OneToMany)(() => ProductCostItem, (ci) => ci.product, { cascade: true }),
    __metadata("design:type", Array)
], Product.prototype, "costItems", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'created_at' }),
    __metadata("design:type", Date)
], Product.prototype, "createdAt", void 0);
__decorate([
    (0, typeorm_1.UpdateDateColumn)({ name: 'updated_at' }),
    __metadata("design:type", Date)
], Product.prototype, "updatedAt", void 0);
exports.Product = Product = __decorate([
    (0, typeorm_1.Entity)('products')
], Product);
let CostType = class CostType {
};
exports.CostType = CostType;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)(),
    __metadata("design:type", Number)
], CostType.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ unique: true, length: 100 }),
    __metadata("design:type", String)
], CostType.prototype, "name", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 500, nullable: true }),
    __metadata("design:type", String)
], CostType.prototype, "description", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'is_active', default: true }),
    __metadata("design:type", Boolean)
], CostType.prototype, "isActive", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'sort_order', default: 0 }),
    __metadata("design:type", Number)
], CostType.prototype, "sortOrder", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'created_at' }),
    __metadata("design:type", Date)
], CostType.prototype, "createdAt", void 0);
exports.CostType = CostType = __decorate([
    (0, typeorm_1.Entity)('cost_types')
], CostType);
let ProductCostItem = class ProductCostItem {
};
exports.ProductCostItem = ProductCostItem;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)(),
    __metadata("design:type", Number)
], ProductCostItem.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => Product, (p) => p.costItems),
    (0, typeorm_1.JoinColumn)({ name: 'product_id' }),
    __metadata("design:type", Product)
], ProductCostItem.prototype, "product", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => CostType),
    (0, typeorm_1.JoinColumn)({ name: 'cost_type_id' }),
    __metadata("design:type", CostType)
], ProductCostItem.prototype, "costType", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'decimal', precision: 18, scale: 2 }),
    __metadata("design:type", Number)
], ProductCostItem.prototype, "amount", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'calculation_type', length: 20, default: 'FIXED' }),
    __metadata("design:type", String)
], ProductCostItem.prototype, "calculationType", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 200, nullable: true }),
    __metadata("design:type", String)
], ProductCostItem.prototype, "notes", void 0);
exports.ProductCostItem = ProductCostItem = __decorate([
    (0, typeorm_1.Entity)('product_cost_items')
], ProductCostItem);
let ProductBatch = class ProductBatch {
};
exports.ProductBatch = ProductBatch;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)(),
    __metadata("design:type", Number)
], ProductBatch.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => Product),
    (0, typeorm_1.JoinColumn)({ name: 'product_id' }),
    __metadata("design:type", Product)
], ProductBatch.prototype, "product", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'batch_number', length: 50 }),
    __metadata("design:type", String)
], ProductBatch.prototype, "batchNumber", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'manufacturing_date', type: 'date', nullable: true }),
    __metadata("design:type", Date)
], ProductBatch.prototype, "manufacturingDate", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'expiry_date', type: 'date', nullable: true }),
    __metadata("design:type", Date)
], ProductBatch.prototype, "expiryDate", void 0);
__decorate([
    (0, typeorm_1.Column)({ default: 0 }),
    __metadata("design:type", Number)
], ProductBatch.prototype, "quantity", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'cost_price', type: 'decimal', precision: 18, scale: 2, nullable: true }),
    __metadata("design:type", Number)
], ProductBatch.prototype, "costPrice", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'supplier_name', length: 200, nullable: true }),
    __metadata("design:type", String)
], ProductBatch.prototype, "supplierName", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 500, nullable: true }),
    __metadata("design:type", String)
], ProductBatch.prototype, "notes", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'is_active', default: true }),
    __metadata("design:type", Boolean)
], ProductBatch.prototype, "isActive", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'created_at' }),
    __metadata("design:type", Date)
], ProductBatch.prototype, "createdAt", void 0);
exports.ProductBatch = ProductBatch = __decorate([
    (0, typeorm_1.Entity)('product_batches')
], ProductBatch);
let UnitConversion = class UnitConversion {
};
exports.UnitConversion = UnitConversion;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)(),
    __metadata("design:type", Number)
], UnitConversion.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => Product),
    (0, typeorm_1.JoinColumn)({ name: 'product_id' }),
    __metadata("design:type", Product)
], UnitConversion.prototype, "product", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'from_unit', length: 30 }),
    __metadata("design:type", String)
], UnitConversion.prototype, "fromUnit", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'to_unit', length: 30 }),
    __metadata("design:type", String)
], UnitConversion.prototype, "toUnit", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'conversion_rate', type: 'decimal', precision: 18, scale: 4 }),
    __metadata("design:type", Number)
], UnitConversion.prototype, "conversionRate", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'selling_price_per_unit', type: 'decimal', precision: 18, scale: 2, nullable: true }),
    __metadata("design:type", Number)
], UnitConversion.prototype, "sellingPricePerUnit", void 0);
exports.UnitConversion = UnitConversion = __decorate([
    (0, typeorm_1.Entity)('unit_conversions')
], UnitConversion);
let ProductPriceHistory = class ProductPriceHistory {
};
exports.ProductPriceHistory = ProductPriceHistory;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)(),
    __metadata("design:type", Number)
], ProductPriceHistory.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => Product),
    (0, typeorm_1.JoinColumn)({ name: 'product_id' }),
    __metadata("design:type", Product)
], ProductPriceHistory.prototype, "product", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'price_type', length: 30 }),
    __metadata("design:type", String)
], ProductPriceHistory.prototype, "priceType", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'old_price', type: 'decimal', precision: 18, scale: 2 }),
    __metadata("design:type", Number)
], ProductPriceHistory.prototype, "oldPrice", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'new_price', type: 'decimal', precision: 18, scale: 2 }),
    __metadata("design:type", Number)
], ProductPriceHistory.prototype, "newPrice", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'change_reason', length: 500, nullable: true }),
    __metadata("design:type", String)
], ProductPriceHistory.prototype, "changeReason", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'changed_by', nullable: true }),
    __metadata("design:type", Number)
], ProductPriceHistory.prototype, "changedBy", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'changed_at' }),
    __metadata("design:type", Date)
], ProductPriceHistory.prototype, "changedAt", void 0);
exports.ProductPriceHistory = ProductPriceHistory = __decorate([
    (0, typeorm_1.Entity)('product_price_history')
], ProductPriceHistory);
//# sourceMappingURL=entities.js.map