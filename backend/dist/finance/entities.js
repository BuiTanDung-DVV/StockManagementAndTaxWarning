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
exports.DailyClosing = exports.CashflowForecast = exports.BudgetPlan = exports.CashTransaction = exports.CashAccount = void 0;
const typeorm_1 = require("typeorm");
let CashAccount = class CashAccount {
};
exports.CashAccount = CashAccount;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)(),
    __metadata("design:type", Number)
], CashAccount.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 100 }),
    __metadata("design:type", String)
], CashAccount.prototype, "name", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'account_type', length: 20 }),
    __metadata("design:type", String)
], CashAccount.prototype, "accountType", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'decimal', precision: 18, scale: 2, default: 0 }),
    __metadata("design:type", Number)
], CashAccount.prototype, "balance", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'is_active', default: true }),
    __metadata("design:type", Boolean)
], CashAccount.prototype, "isActive", void 0);
exports.CashAccount = CashAccount = __decorate([
    (0, typeorm_1.Entity)('cash_accounts')
], CashAccount);
let CashTransaction = class CashTransaction {
};
exports.CashTransaction = CashTransaction;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)(),
    __metadata("design:type", Number)
], CashTransaction.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'transaction_code', unique: true, length: 20 }),
    __metadata("design:type", String)
], CashTransaction.prototype, "transactionCode", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 10 }),
    __metadata("design:type", String)
], CashTransaction.prototype, "type", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 50 }),
    __metadata("design:type", String)
], CashTransaction.prototype, "category", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'decimal', precision: 18, scale: 2 }),
    __metadata("design:type", Number)
], CashTransaction.prototype, "amount", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'payment_method', length: 10, default: 'CASH' }),
    __metadata("design:type", String)
], CashTransaction.prototype, "paymentMethod", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => CashAccount, { nullable: true }),
    (0, typeorm_1.JoinColumn)({ name: 'account_id' }),
    __metadata("design:type", CashAccount)
], CashTransaction.prototype, "account", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 200, nullable: true }),
    __metadata("design:type", String)
], CashTransaction.prototype, "counterparty", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'reference_type', length: 20, nullable: true }),
    __metadata("design:type", String)
], CashTransaction.prototype, "referenceType", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'reference_id', nullable: true }),
    __metadata("design:type", Number)
], CashTransaction.prototype, "referenceId", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'transaction_date', type: 'date' }),
    __metadata("design:type", Date)
], CashTransaction.prototype, "transactionDate", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 500, nullable: true }),
    __metadata("design:type", String)
], CashTransaction.prototype, "notes", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'receipt_image_url', length: 1000, nullable: true }),
    __metadata("design:type", String)
], CashTransaction.prototype, "receiptImageUrl", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'running_balance', type: 'decimal', precision: 18, scale: 2, nullable: true }),
    __metadata("design:type", Number)
], CashTransaction.prototype, "runningBalance", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'approved_by', nullable: true }),
    __metadata("design:type", Number)
], CashTransaction.prototype, "approvedBy", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'created_by', nullable: true }),
    __metadata("design:type", Number)
], CashTransaction.prototype, "createdBy", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'created_at' }),
    __metadata("design:type", Date)
], CashTransaction.prototype, "createdAt", void 0);
exports.CashTransaction = CashTransaction = __decorate([
    (0, typeorm_1.Entity)('cash_transactions')
], CashTransaction);
let BudgetPlan = class BudgetPlan {
};
exports.BudgetPlan = BudgetPlan;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)(),
    __metadata("design:type", Number)
], BudgetPlan.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 200 }),
    __metadata("design:type", String)
], BudgetPlan.prototype, "name", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 20 }),
    __metadata("design:type", String)
], BudgetPlan.prototype, "period", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'start_date', type: 'date' }),
    __metadata("design:type", Date)
], BudgetPlan.prototype, "startDate", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'end_date', type: 'date' }),
    __metadata("design:type", Date)
], BudgetPlan.prototype, "endDate", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'planned_income', type: 'decimal', precision: 18, scale: 2, default: 0 }),
    __metadata("design:type", Number)
], BudgetPlan.prototype, "plannedIncome", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'planned_expense', type: 'decimal', precision: 18, scale: 2, default: 0 }),
    __metadata("design:type", Number)
], BudgetPlan.prototype, "plannedExpense", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'actual_income', type: 'decimal', precision: 18, scale: 2, default: 0 }),
    __metadata("design:type", Number)
], BudgetPlan.prototype, "actualIncome", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'actual_expense', type: 'decimal', precision: 18, scale: 2, default: 0 }),
    __metadata("design:type", Number)
], BudgetPlan.prototype, "actualExpense", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 500, nullable: true }),
    __metadata("design:type", String)
], BudgetPlan.prototype, "notes", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'created_at' }),
    __metadata("design:type", Date)
], BudgetPlan.prototype, "createdAt", void 0);
exports.BudgetPlan = BudgetPlan = __decorate([
    (0, typeorm_1.Entity)('budget_plans')
], BudgetPlan);
let CashflowForecast = class CashflowForecast {
};
exports.CashflowForecast = CashflowForecast;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)(),
    __metadata("design:type", Number)
], CashflowForecast.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'forecast_date', type: 'date' }),
    __metadata("design:type", Date)
], CashflowForecast.prototype, "forecastDate", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'expected_income', type: 'decimal', precision: 18, scale: 2, default: 0 }),
    __metadata("design:type", Number)
], CashflowForecast.prototype, "expectedIncome", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'expected_expense', type: 'decimal', precision: 18, scale: 2, default: 0 }),
    __metadata("design:type", Number)
], CashflowForecast.prototype, "expectedExpense", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'expected_balance', type: 'decimal', precision: 18, scale: 2, default: 0 }),
    __metadata("design:type", Number)
], CashflowForecast.prototype, "expectedBalance", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 500, nullable: true }),
    __metadata("design:type", String)
], CashflowForecast.prototype, "notes", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'created_at' }),
    __metadata("design:type", Date)
], CashflowForecast.prototype, "createdAt", void 0);
exports.CashflowForecast = CashflowForecast = __decorate([
    (0, typeorm_1.Entity)('cashflow_forecasts')
], CashflowForecast);
let DailyClosing = class DailyClosing {
};
exports.DailyClosing = DailyClosing;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)(),
    __metadata("design:type", Number)
], DailyClosing.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'closing_date', type: 'date', unique: true }),
    __metadata("design:type", Date)
], DailyClosing.prototype, "closingDate", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'opening_cash', type: 'decimal', precision: 18, scale: 2, default: 0 }),
    __metadata("design:type", Number)
], DailyClosing.prototype, "openingCash", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'closing_cash', type: 'decimal', precision: 18, scale: 2, default: 0 }),
    __metadata("design:type", Number)
], DailyClosing.prototype, "closingCash", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'expected_cash', type: 'decimal', precision: 18, scale: 2, default: 0 }),
    __metadata("design:type", Number)
], DailyClosing.prototype, "expectedCash", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'cash_difference', type: 'decimal', precision: 18, scale: 2, default: 0 }),
    __metadata("design:type", Number)
], DailyClosing.prototype, "cashDifference", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'total_sales', type: 'decimal', precision: 18, scale: 2, default: 0 }),
    __metadata("design:type", Number)
], DailyClosing.prototype, "totalSales", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'total_returns', type: 'decimal', precision: 18, scale: 2, default: 0 }),
    __metadata("design:type", Number)
], DailyClosing.prototype, "totalReturns", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'total_income', type: 'decimal', precision: 18, scale: 2, default: 0 }),
    __metadata("design:type", Number)
], DailyClosing.prototype, "totalIncome", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'total_expense', type: 'decimal', precision: 18, scale: 2, default: 0 }),
    __metadata("design:type", Number)
], DailyClosing.prototype, "totalExpense", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'order_count', default: 0 }),
    __metadata("design:type", Number)
], DailyClosing.prototype, "orderCount", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 500, nullable: true }),
    __metadata("design:type", String)
], DailyClosing.prototype, "notes", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'closed_by', nullable: true }),
    __metadata("design:type", Number)
], DailyClosing.prototype, "closedBy", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'closed_at' }),
    __metadata("design:type", Date)
], DailyClosing.prototype, "closedAt", void 0);
exports.DailyClosing = DailyClosing = __decorate([
    (0, typeorm_1.Entity)('daily_closings')
], DailyClosing);
//# sourceMappingURL=entities.js.map