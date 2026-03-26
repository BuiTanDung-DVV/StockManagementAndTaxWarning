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
exports.PurchaseWithoutInvoiceController = exports.InvoiceController = exports.InvoiceScanController = exports.ActivityLogController = exports.ShopProfileController = void 0;
const common_1 = require("@nestjs/common");
const system_service_1 = require("./system.service");
const response_1 = require("../common/response");
let ShopProfileController = class ShopProfileController {
    constructor(svc) {
        this.svc = svc;
    }
    async get() { return response_1.ApiResponse.ok(await this.svc.getShopProfile()); }
    async save(dto) { return response_1.ApiResponse.ok(await this.svc.saveShopProfile(dto)); }
};
exports.ShopProfileController = ShopProfileController;
__decorate([
    (0, common_1.Get)(),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", Promise)
], ShopProfileController.prototype, "get", null);
__decorate([
    (0, common_1.Post)(),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], ShopProfileController.prototype, "save", null);
exports.ShopProfileController = ShopProfileController = __decorate([
    (0, common_1.Controller)('shop-profile'),
    __metadata("design:paramtypes", [system_service_1.SystemService])
], ShopProfileController);
let ActivityLogController = class ActivityLogController {
    constructor(svc) {
        this.svc = svc;
    }
    async findAll(page = '1', limit = '50') {
        return response_1.ApiResponse.ok(await this.svc.getLogs(+page, +limit));
    }
};
exports.ActivityLogController = ActivityLogController;
__decorate([
    (0, common_1.Get)(),
    __param(0, (0, common_1.Query)('page')),
    __param(1, (0, common_1.Query)('limit')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object]),
    __metadata("design:returntype", Promise)
], ActivityLogController.prototype, "findAll", null);
exports.ActivityLogController = ActivityLogController = __decorate([
    (0, common_1.Controller)('activity-logs'),
    __metadata("design:paramtypes", [system_service_1.SystemService])
], ActivityLogController);
let InvoiceScanController = class InvoiceScanController {
    constructor(svc) {
        this.svc = svc;
    }
    async findAll(page = '1', limit = '20') { return response_1.ApiResponse.ok(await this.svc.findScans(+page, +limit)); }
    async create(dto) { return response_1.ApiResponse.ok(await this.svc.createScan(dto)); }
    async update(id, dto) { return response_1.ApiResponse.ok(await this.svc.updateScan(id, dto)); }
};
exports.InvoiceScanController = InvoiceScanController;
__decorate([
    (0, common_1.Get)(),
    __param(0, (0, common_1.Query)('page')),
    __param(1, (0, common_1.Query)('limit')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object]),
    __metadata("design:returntype", Promise)
], InvoiceScanController.prototype, "findAll", null);
__decorate([
    (0, common_1.Post)(),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], InvoiceScanController.prototype, "create", null);
__decorate([
    (0, common_1.Put)(':id'),
    __param(0, (0, common_1.Param)('id', common_1.ParseIntPipe)),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number, Object]),
    __metadata("design:returntype", Promise)
], InvoiceScanController.prototype, "update", null);
exports.InvoiceScanController = InvoiceScanController = __decorate([
    (0, common_1.Controller)('invoice-scans'),
    __metadata("design:paramtypes", [system_service_1.SystemService])
], InvoiceScanController);
let InvoiceController = class InvoiceController {
    constructor(svc) {
        this.svc = svc;
    }
    async findAll(page = '1', limit = '20', type, from, to) {
        return response_1.ApiResponse.ok(await this.svc.findInvoices(+page, +limit, type, from ? new Date(from) : undefined, to ? new Date(to) : undefined));
    }
    async summary(from, to) {
        return response_1.ApiResponse.ok(await this.svc.getInvoiceSummary(new Date(from), new Date(to)));
    }
    async findOne(id) { return response_1.ApiResponse.ok(await this.svc.findInvoiceById(id)); }
    async create(dto) { return response_1.ApiResponse.ok(await this.svc.createInvoice(dto)); }
};
exports.InvoiceController = InvoiceController;
__decorate([
    (0, common_1.Get)(),
    __param(0, (0, common_1.Query)('page')),
    __param(1, (0, common_1.Query)('limit')),
    __param(2, (0, common_1.Query)('type')),
    __param(3, (0, common_1.Query)('from')),
    __param(4, (0, common_1.Query)('to')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object, String, String, String]),
    __metadata("design:returntype", Promise)
], InvoiceController.prototype, "findAll", null);
__decorate([
    (0, common_1.Get)('summary'),
    __param(0, (0, common_1.Query)('from')),
    __param(1, (0, common_1.Query)('to')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String]),
    __metadata("design:returntype", Promise)
], InvoiceController.prototype, "summary", null);
__decorate([
    (0, common_1.Get)(':id'),
    __param(0, (0, common_1.Param)('id', common_1.ParseIntPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number]),
    __metadata("design:returntype", Promise)
], InvoiceController.prototype, "findOne", null);
__decorate([
    (0, common_1.Post)(),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], InvoiceController.prototype, "create", null);
exports.InvoiceController = InvoiceController = __decorate([
    (0, common_1.Controller)('invoices'),
    __metadata("design:paramtypes", [system_service_1.SystemService])
], InvoiceController);
let PurchaseWithoutInvoiceController = class PurchaseWithoutInvoiceController {
    constructor(svc) {
        this.svc = svc;
    }
    async findAll(page = '1', limit = '20') {
        return response_1.ApiResponse.ok(await this.svc.findPurchasesWithoutInvoice(+page, +limit));
    }
    async create(dto) { return response_1.ApiResponse.ok(await this.svc.createPurchaseWithoutInvoice(dto)); }
};
exports.PurchaseWithoutInvoiceController = PurchaseWithoutInvoiceController;
__decorate([
    (0, common_1.Get)(),
    __param(0, (0, common_1.Query)('page')),
    __param(1, (0, common_1.Query)('limit')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object]),
    __metadata("design:returntype", Promise)
], PurchaseWithoutInvoiceController.prototype, "findAll", null);
__decorate([
    (0, common_1.Post)(),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], PurchaseWithoutInvoiceController.prototype, "create", null);
exports.PurchaseWithoutInvoiceController = PurchaseWithoutInvoiceController = __decorate([
    (0, common_1.Controller)('purchases-without-invoice'),
    __metadata("design:paramtypes", [system_service_1.SystemService])
], PurchaseWithoutInvoiceController);
//# sourceMappingURL=system.controller.js.map