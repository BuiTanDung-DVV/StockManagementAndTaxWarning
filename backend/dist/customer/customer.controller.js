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
exports.CustomerController = void 0;
const common_1 = require("@nestjs/common");
const customer_service_1 = require("./customer.service");
const response_1 = require("../common/response");
let CustomerController = class CustomerController {
    constructor(svc) {
        this.svc = svc;
    }
    async findAll(page = '1', limit = '20', search) {
        return response_1.ApiResponse.ok(await this.svc.findAll(+page, +limit, search));
    }
    async overdueDebts() { return response_1.ApiResponse.ok(await this.svc.findOverdueDebts()); }
    async debtAging() { return response_1.ApiResponse.ok(await this.svc.getDebtAging()); }
    async findOne(id) {
        return response_1.ApiResponse.ok(await this.svc.findById(id));
    }
    async create(dto) { return response_1.ApiResponse.ok(await this.svc.create(dto)); }
    async update(id, dto) {
        return response_1.ApiResponse.ok(await this.svc.update(id, dto));
    }
    async receivables(id) {
        return response_1.ApiResponse.ok(await this.svc.findReceivables(id));
    }
    async createReceivable(id, dto) {
        return response_1.ApiResponse.ok(await this.svc.createReceivable(id, dto));
    }
    async addEvidence(receivableId, dto) {
        return response_1.ApiResponse.ok(await this.svc.addEvidence(receivableId, dto));
    }
    async addPayment(receivableId, dto) {
        return response_1.ApiResponse.ok(await this.svc.addPayment(receivableId, dto));
    }
};
exports.CustomerController = CustomerController;
__decorate([
    (0, common_1.Get)(),
    __param(0, (0, common_1.Query)('page')),
    __param(1, (0, common_1.Query)('limit')),
    __param(2, (0, common_1.Query)('search')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object, String]),
    __metadata("design:returntype", Promise)
], CustomerController.prototype, "findAll", null);
__decorate([
    (0, common_1.Get)('overdue-debts'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", Promise)
], CustomerController.prototype, "overdueDebts", null);
__decorate([
    (0, common_1.Get)('debt-aging'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", Promise)
], CustomerController.prototype, "debtAging", null);
__decorate([
    (0, common_1.Get)(':id'),
    __param(0, (0, common_1.Param)('id', common_1.ParseIntPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number]),
    __metadata("design:returntype", Promise)
], CustomerController.prototype, "findOne", null);
__decorate([
    (0, common_1.Post)(),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], CustomerController.prototype, "create", null);
__decorate([
    (0, common_1.Put)(':id'),
    __param(0, (0, common_1.Param)('id', common_1.ParseIntPipe)),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number, Object]),
    __metadata("design:returntype", Promise)
], CustomerController.prototype, "update", null);
__decorate([
    (0, common_1.Get)(':id/receivables'),
    __param(0, (0, common_1.Param)('id', common_1.ParseIntPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number]),
    __metadata("design:returntype", Promise)
], CustomerController.prototype, "receivables", null);
__decorate([
    (0, common_1.Post)(':id/receivables'),
    __param(0, (0, common_1.Param)('id', common_1.ParseIntPipe)),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number, Object]),
    __metadata("design:returntype", Promise)
], CustomerController.prototype, "createReceivable", null);
__decorate([
    (0, common_1.Post)('receivables/:receivableId/evidence'),
    __param(0, (0, common_1.Param)('receivableId', common_1.ParseIntPipe)),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number, Object]),
    __metadata("design:returntype", Promise)
], CustomerController.prototype, "addEvidence", null);
__decorate([
    (0, common_1.Post)('receivables/:receivableId/payments'),
    __param(0, (0, common_1.Param)('receivableId', common_1.ParseIntPipe)),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number, Object]),
    __metadata("design:returntype", Promise)
], CustomerController.prototype, "addPayment", null);
exports.CustomerController = CustomerController = __decorate([
    (0, common_1.Controller)('customers'),
    __metadata("design:paramtypes", [customer_service_1.CustomerService])
], CustomerController);
//# sourceMappingURL=customer.controller.js.map