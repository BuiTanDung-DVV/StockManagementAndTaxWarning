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
exports.BudgetPlanController = exports.CashflowForecastController = exports.CashAccountController = exports.DailyClosingController = exports.CashTransactionController = void 0;
const common_1 = require("@nestjs/common");
const finance_service_1 = require("./finance.service");
const response_1 = require("../common/response");
let CashTransactionController = class CashTransactionController {
    constructor(svc) {
        this.svc = svc;
    }
    async findAll(page = '1', limit = '20', type, from, to) {
        return response_1.ApiResponse.ok(await this.svc.findTransactions(+page, +limit, type, from ? new Date(from) : undefined, to ? new Date(to) : undefined));
    }
    async create(dto) { return response_1.ApiResponse.ok(await this.svc.createTransaction(dto)); }
    async summary(from, to) {
        return response_1.ApiResponse.ok(await this.svc.getCashFlowSummary(new Date(from), new Date(to)));
    }
    async profitLoss(from, to) {
        return response_1.ApiResponse.ok(await this.svc.getProfitLossReport(new Date(from), new Date(to)));
    }
};
exports.CashTransactionController = CashTransactionController;
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
], CashTransactionController.prototype, "findAll", null);
__decorate([
    (0, common_1.Post)(),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], CashTransactionController.prototype, "create", null);
__decorate([
    (0, common_1.Get)('summary'),
    __param(0, (0, common_1.Query)('from')),
    __param(1, (0, common_1.Query)('to')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String]),
    __metadata("design:returntype", Promise)
], CashTransactionController.prototype, "summary", null);
__decorate([
    (0, common_1.Get)('profit-loss'),
    __param(0, (0, common_1.Query)('from')),
    __param(1, (0, common_1.Query)('to')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String]),
    __metadata("design:returntype", Promise)
], CashTransactionController.prototype, "profitLoss", null);
exports.CashTransactionController = CashTransactionController = __decorate([
    (0, common_1.Controller)('cash-transactions'),
    __metadata("design:paramtypes", [finance_service_1.FinanceService])
], CashTransactionController);
let DailyClosingController = class DailyClosingController {
    constructor(svc) {
        this.svc = svc;
    }
    async get(date) { return response_1.ApiResponse.ok(await this.svc.getDailyClosing(date)); }
    async create(dto) { return response_1.ApiResponse.ok(await this.svc.createDailyClosing(dto)); }
};
exports.DailyClosingController = DailyClosingController;
__decorate([
    (0, common_1.Get)(),
    __param(0, (0, common_1.Query)('date')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], DailyClosingController.prototype, "get", null);
__decorate([
    (0, common_1.Post)(),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], DailyClosingController.prototype, "create", null);
exports.DailyClosingController = DailyClosingController = __decorate([
    (0, common_1.Controller)('daily-closings'),
    __metadata("design:paramtypes", [finance_service_1.FinanceService])
], DailyClosingController);
let CashAccountController = class CashAccountController {
    constructor(svc) {
        this.svc = svc;
    }
    async findAll() { return response_1.ApiResponse.ok(await this.svc.findAccounts()); }
};
exports.CashAccountController = CashAccountController;
__decorate([
    (0, common_1.Get)(),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", Promise)
], CashAccountController.prototype, "findAll", null);
exports.CashAccountController = CashAccountController = __decorate([
    (0, common_1.Controller)('cash-accounts'),
    __metadata("design:paramtypes", [finance_service_1.FinanceService])
], CashAccountController);
let CashflowForecastController = class CashflowForecastController {
    constructor(svc) {
        this.svc = svc;
    }
    async findAll(from, to) {
        return response_1.ApiResponse.ok(await this.svc.findForecasts(from ? new Date(from) : undefined, to ? new Date(to) : undefined));
    }
    async create(dto) { return response_1.ApiResponse.ok(await this.svc.createForecast(dto)); }
    async update(id, dto) { return response_1.ApiResponse.ok(await this.svc.updateForecast(id, dto)); }
    async delete(id) { return response_1.ApiResponse.ok(await this.svc.deleteForecast(id)); }
};
exports.CashflowForecastController = CashflowForecastController;
__decorate([
    (0, common_1.Get)(),
    __param(0, (0, common_1.Query)('from')),
    __param(1, (0, common_1.Query)('to')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String]),
    __metadata("design:returntype", Promise)
], CashflowForecastController.prototype, "findAll", null);
__decorate([
    (0, common_1.Post)(),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], CashflowForecastController.prototype, "create", null);
__decorate([
    (0, common_1.Put)(':id'),
    __param(0, (0, common_1.Param)('id', common_1.ParseIntPipe)),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number, Object]),
    __metadata("design:returntype", Promise)
], CashflowForecastController.prototype, "update", null);
__decorate([
    (0, common_1.Delete)(':id'),
    __param(0, (0, common_1.Param)('id', common_1.ParseIntPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number]),
    __metadata("design:returntype", Promise)
], CashflowForecastController.prototype, "delete", null);
exports.CashflowForecastController = CashflowForecastController = __decorate([
    (0, common_1.Controller)('cashflow-forecasts'),
    __metadata("design:paramtypes", [finance_service_1.FinanceService])
], CashflowForecastController);
let BudgetPlanController = class BudgetPlanController {
    constructor(svc) {
        this.svc = svc;
    }
    async findAll() { return response_1.ApiResponse.ok(await this.svc.findBudgetPlans()); }
    async create(dto) { return response_1.ApiResponse.ok(await this.svc.createBudgetPlan(dto)); }
    async update(id, dto) { return response_1.ApiResponse.ok(await this.svc.updateBudgetPlan(id, dto)); }
    async delete(id) { return response_1.ApiResponse.ok(await this.svc.deleteBudgetPlan(id)); }
};
exports.BudgetPlanController = BudgetPlanController;
__decorate([
    (0, common_1.Get)(),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", Promise)
], BudgetPlanController.prototype, "findAll", null);
__decorate([
    (0, common_1.Post)(),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], BudgetPlanController.prototype, "create", null);
__decorate([
    (0, common_1.Put)(':id'),
    __param(0, (0, common_1.Param)('id', common_1.ParseIntPipe)),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number, Object]),
    __metadata("design:returntype", Promise)
], BudgetPlanController.prototype, "update", null);
__decorate([
    (0, common_1.Delete)(':id'),
    __param(0, (0, common_1.Param)('id', common_1.ParseIntPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number]),
    __metadata("design:returntype", Promise)
], BudgetPlanController.prototype, "delete", null);
exports.BudgetPlanController = BudgetPlanController = __decorate([
    (0, common_1.Controller)('budget-plans'),
    __metadata("design:paramtypes", [finance_service_1.FinanceService])
], BudgetPlanController);
//# sourceMappingURL=finance.controller.js.map