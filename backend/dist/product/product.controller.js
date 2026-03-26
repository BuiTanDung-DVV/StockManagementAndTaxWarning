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
exports.CostTypeController = exports.CategoryController = exports.ProductController = void 0;
const common_1 = require("@nestjs/common");
const product_service_1 = require("./product.service");
const response_1 = require("../common/response");
let ProductController = class ProductController {
    constructor(svc) {
        this.svc = svc;
    }
    async findAll(page = '1', limit = '20', search) {
        return response_1.ApiResponse.ok(await this.svc.findAllProducts(+page, +limit, search));
    }
    async findOne(id) {
        return response_1.ApiResponse.ok(await this.svc.findProductById(id));
    }
    async create(dto) {
        return response_1.ApiResponse.ok(await this.svc.createProduct(dto), 'Product created');
    }
    async update(id, dto) {
        return response_1.ApiResponse.ok(await this.svc.updateProduct(id, dto), 'Product updated');
    }
    async remove(id) {
        return response_1.ApiResponse.ok(await this.svc.deleteProduct(id), 'Product deactivated');
    }
    async calculatePrice(id) {
        return response_1.ApiResponse.ok(await this.svc.calculateSuggestedPrice(id));
    }
    async addCostItem(id, dto) {
        return response_1.ApiResponse.ok(await this.svc.addCostItem(id, dto.costTypeId, dto.amount, dto.calculationType, dto.notes));
    }
    async removeCostItem(itemId) {
        await this.svc.removeCostItem(itemId);
        return response_1.ApiResponse.ok(null, 'Cost item removed');
    }
    async priceHistory(id) {
        return response_1.ApiResponse.ok(await this.svc.getPriceHistory(id));
    }
    async batches(id) {
        return response_1.ApiResponse.ok(await this.svc.findBatches(id));
    }
    async createBatch(id, dto) {
        return response_1.ApiResponse.ok(await this.svc.createBatch(id, dto));
    }
    async conversions(id) {
        return response_1.ApiResponse.ok(await this.svc.findConversions(id));
    }
    async createConversion(id, dto) {
        return response_1.ApiResponse.ok(await this.svc.createConversion(id, dto));
    }
};
exports.ProductController = ProductController;
__decorate([
    (0, common_1.Get)(),
    __param(0, (0, common_1.Query)('page')),
    __param(1, (0, common_1.Query)('limit')),
    __param(2, (0, common_1.Query)('search')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object, String]),
    __metadata("design:returntype", Promise)
], ProductController.prototype, "findAll", null);
__decorate([
    (0, common_1.Get)(':id'),
    __param(0, (0, common_1.Param)('id', common_1.ParseIntPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number]),
    __metadata("design:returntype", Promise)
], ProductController.prototype, "findOne", null);
__decorate([
    (0, common_1.Post)(),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], ProductController.prototype, "create", null);
__decorate([
    (0, common_1.Put)(':id'),
    __param(0, (0, common_1.Param)('id', common_1.ParseIntPipe)),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number, Object]),
    __metadata("design:returntype", Promise)
], ProductController.prototype, "update", null);
__decorate([
    (0, common_1.Delete)(':id'),
    __param(0, (0, common_1.Param)('id', common_1.ParseIntPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number]),
    __metadata("design:returntype", Promise)
], ProductController.prototype, "remove", null);
__decorate([
    (0, common_1.Post)(':id/calculate-price'),
    __param(0, (0, common_1.Param)('id', common_1.ParseIntPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number]),
    __metadata("design:returntype", Promise)
], ProductController.prototype, "calculatePrice", null);
__decorate([
    (0, common_1.Post)(':id/cost-items'),
    __param(0, (0, common_1.Param)('id', common_1.ParseIntPipe)),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number, Object]),
    __metadata("design:returntype", Promise)
], ProductController.prototype, "addCostItem", null);
__decorate([
    (0, common_1.Delete)('cost-items/:itemId'),
    __param(0, (0, common_1.Param)('itemId', common_1.ParseIntPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number]),
    __metadata("design:returntype", Promise)
], ProductController.prototype, "removeCostItem", null);
__decorate([
    (0, common_1.Get)(':id/price-history'),
    __param(0, (0, common_1.Param)('id', common_1.ParseIntPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number]),
    __metadata("design:returntype", Promise)
], ProductController.prototype, "priceHistory", null);
__decorate([
    (0, common_1.Get)(':id/batches'),
    __param(0, (0, common_1.Param)('id', common_1.ParseIntPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number]),
    __metadata("design:returntype", Promise)
], ProductController.prototype, "batches", null);
__decorate([
    (0, common_1.Post)(':id/batches'),
    __param(0, (0, common_1.Param)('id', common_1.ParseIntPipe)),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number, Object]),
    __metadata("design:returntype", Promise)
], ProductController.prototype, "createBatch", null);
__decorate([
    (0, common_1.Get)(':id/conversions'),
    __param(0, (0, common_1.Param)('id', common_1.ParseIntPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number]),
    __metadata("design:returntype", Promise)
], ProductController.prototype, "conversions", null);
__decorate([
    (0, common_1.Post)(':id/conversions'),
    __param(0, (0, common_1.Param)('id', common_1.ParseIntPipe)),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number, Object]),
    __metadata("design:returntype", Promise)
], ProductController.prototype, "createConversion", null);
exports.ProductController = ProductController = __decorate([
    (0, common_1.Controller)('products'),
    __metadata("design:paramtypes", [product_service_1.ProductService])
], ProductController);
let CategoryController = class CategoryController {
    constructor(svc) {
        this.svc = svc;
    }
    async findAll() { return response_1.ApiResponse.ok(await this.svc.findAllCategories()); }
    async create(dto) { return response_1.ApiResponse.ok(await this.svc.createCategory(dto)); }
};
exports.CategoryController = CategoryController;
__decorate([
    (0, common_1.Get)(),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", Promise)
], CategoryController.prototype, "findAll", null);
__decorate([
    (0, common_1.Post)(),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], CategoryController.prototype, "create", null);
exports.CategoryController = CategoryController = __decorate([
    (0, common_1.Controller)('categories'),
    __metadata("design:paramtypes", [product_service_1.ProductService])
], CategoryController);
let CostTypeController = class CostTypeController {
    constructor(svc) {
        this.svc = svc;
    }
    async findAll() { return response_1.ApiResponse.ok(await this.svc.findAllCostTypes()); }
    async create(dto) { return response_1.ApiResponse.ok(await this.svc.createCostType(dto)); }
};
exports.CostTypeController = CostTypeController;
__decorate([
    (0, common_1.Get)(),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", Promise)
], CostTypeController.prototype, "findAll", null);
__decorate([
    (0, common_1.Post)(),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], CostTypeController.prototype, "create", null);
exports.CostTypeController = CostTypeController = __decorate([
    (0, common_1.Controller)('cost-types'),
    __metadata("design:paramtypes", [product_service_1.ProductService])
], CostTypeController);
//# sourceMappingURL=product.controller.js.map