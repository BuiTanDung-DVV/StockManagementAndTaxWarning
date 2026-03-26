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
exports.StockTakeController = exports.PurchaseOrderController = exports.InventoryController = void 0;
const common_1 = require("@nestjs/common");
const inventory_service_1 = require("./inventory.service");
const response_1 = require("../common/response");
let InventoryController = class InventoryController {
    constructor(svc) {
        this.svc = svc;
    }
    async stock(wid) { return response_1.ApiResponse.ok(await this.svc.getCurrentStock(wid ? +wid : undefined)); }
    async lowStock(t) { return response_1.ApiResponse.ok(await this.svc.getLowStock(t ? +t : undefined)); }
    async movements(pid, page = '1', limit = '20') {
        return response_1.ApiResponse.ok(await this.svc.getMovements(pid ? +pid : undefined, +page, +limit));
    }
    async warehouses() { return response_1.ApiResponse.ok(await this.svc.findWarehouses()); }
    async createWarehouse(dto) { return response_1.ApiResponse.ok(await this.svc.createWarehouse(dto)); }
    async xntReport(from, to, wid) {
        return response_1.ApiResponse.ok(await this.svc.getXNTReport(new Date(from), new Date(to), wid ? +wid : undefined));
    }
    async expiringProducts(days) {
        return response_1.ApiResponse.ok(await this.svc.getExpiringProducts(days ? +days : 30));
    }
};
exports.InventoryController = InventoryController;
__decorate([
    (0, common_1.Get)('stock'),
    __param(0, (0, common_1.Query)('warehouseId')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], InventoryController.prototype, "stock", null);
__decorate([
    (0, common_1.Get)('low-stock'),
    __param(0, (0, common_1.Query)('threshold')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], InventoryController.prototype, "lowStock", null);
__decorate([
    (0, common_1.Get)('movements'),
    __param(0, (0, common_1.Query)('productId')),
    __param(1, (0, common_1.Query)('page')),
    __param(2, (0, common_1.Query)('limit')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, Object]),
    __metadata("design:returntype", Promise)
], InventoryController.prototype, "movements", null);
__decorate([
    (0, common_1.Get)('warehouses'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", Promise)
], InventoryController.prototype, "warehouses", null);
__decorate([
    (0, common_1.Post)('warehouses'),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], InventoryController.prototype, "createWarehouse", null);
__decorate([
    (0, common_1.Get)('xnt-report'),
    __param(0, (0, common_1.Query)('from')),
    __param(1, (0, common_1.Query)('to')),
    __param(2, (0, common_1.Query)('warehouseId')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, String]),
    __metadata("design:returntype", Promise)
], InventoryController.prototype, "xntReport", null);
__decorate([
    (0, common_1.Get)('expiring-products'),
    __param(0, (0, common_1.Query)('daysAhead')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], InventoryController.prototype, "expiringProducts", null);
exports.InventoryController = InventoryController = __decorate([
    (0, common_1.Controller)('inventory'),
    __metadata("design:paramtypes", [inventory_service_1.InventoryService])
], InventoryController);
let PurchaseOrderController = class PurchaseOrderController {
    constructor(svc) {
        this.svc = svc;
    }
    async findAll(page = '1', limit = '20') { return response_1.ApiResponse.ok(await this.svc.findPurchaseOrders(+page, +limit)); }
    async create(dto) { return response_1.ApiResponse.ok(await this.svc.createPurchaseOrder(dto)); }
};
exports.PurchaseOrderController = PurchaseOrderController;
__decorate([
    (0, common_1.Get)(),
    __param(0, (0, common_1.Query)('page')),
    __param(1, (0, common_1.Query)('limit')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object]),
    __metadata("design:returntype", Promise)
], PurchaseOrderController.prototype, "findAll", null);
__decorate([
    (0, common_1.Post)(),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], PurchaseOrderController.prototype, "create", null);
exports.PurchaseOrderController = PurchaseOrderController = __decorate([
    (0, common_1.Controller)('purchase-orders'),
    __metadata("design:paramtypes", [inventory_service_1.InventoryService])
], PurchaseOrderController);
let StockTakeController = class StockTakeController {
    constructor(svc) {
        this.svc = svc;
    }
    async create(dto) { return response_1.ApiResponse.ok(await this.svc.createStockTake(dto)); }
};
exports.StockTakeController = StockTakeController;
__decorate([
    (0, common_1.Post)(),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], StockTakeController.prototype, "create", null);
exports.StockTakeController = StockTakeController = __decorate([
    (0, common_1.Controller)('stock-takes'),
    __metadata("design:paramtypes", [inventory_service_1.InventoryService])
], StockTakeController);
//# sourceMappingURL=inventory.controller.js.map