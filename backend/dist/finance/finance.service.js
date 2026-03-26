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
exports.FinanceService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const entities_1 = require("./entities");
let FinanceService = class FinanceService {
    constructor(txRepo, accountRepo, closingRepo, budgetRepo, forecastRepo) {
        this.txRepo = txRepo;
        this.accountRepo = accountRepo;
        this.closingRepo = closingRepo;
        this.budgetRepo = budgetRepo;
        this.forecastRepo = forecastRepo;
    }
    async findTransactions(page = 1, limit = 20, type, from, to) {
        const qb = this.txRepo.createQueryBuilder('t').orderBy('t.createdAt', 'DESC');
        if (type)
            qb.andWhere('t.type = :type', { type });
        if (from && to)
            qb.andWhere('t.transactionDate BETWEEN :from AND :to', { from, to });
        const [items, total] = await qb.skip((page - 1) * limit).take(limit).getManyAndCount();
        return { items, total, page, limit };
    }
    async createTransaction(dto) {
        if (!dto.transactionCode)
            dto.transactionCode = (dto.type === 'INCOME' ? 'TT' : 'CT') + Date.now().toString().slice(-8);
        const lastTx = await this.txRepo.findOne({ order: { createdAt: 'DESC' }, where: {} });
        const lastBalance = lastTx?.runningBalance ? Number(lastTx.runningBalance) : 0;
        dto.runningBalance = dto.type === 'INCOME' ? lastBalance + Number(dto.amount) : lastBalance - Number(dto.amount);
        return this.txRepo.save(this.txRepo.create(dto));
    }
    async getCashFlowSummary(from, to) {
        const income = await this.txRepo.createQueryBuilder('t')
            .select('COALESCE(SUM(t.amount), 0)', 'total')
            .where('t.type = :type', { type: 'INCOME' })
            .andWhere('t.transactionDate BETWEEN :from AND :to', { from, to })
            .getRawOne();
        const expense = await this.txRepo.createQueryBuilder('t')
            .select('COALESCE(SUM(t.amount), 0)', 'total')
            .where('t.type = :type', { type: 'EXPENSE' })
            .andWhere('t.transactionDate BETWEEN :from AND :to', { from, to })
            .getRawOne();
        return { totalIncome: income.total, totalExpense: expense.total, netCashFlow: income.total - expense.total };
    }
    async createDailyClosing(dto) {
        return this.closingRepo.save(this.closingRepo.create(dto));
    }
    async getDailyClosing(date) {
        return this.closingRepo.findOne({ where: { closingDate: new Date(date) } });
    }
    async findAccounts() { return this.accountRepo.find({ where: { isActive: true } }); }
    async findForecasts(from, to) {
        const qb = this.forecastRepo.createQueryBuilder('f').orderBy('f.forecastDate', 'ASC');
        if (from && to)
            qb.where('f.forecastDate BETWEEN :from AND :to', { from, to });
        return qb.getMany();
    }
    async createForecast(dto) {
        dto.expectedBalance = Number(dto.expectedIncome || 0) - Number(dto.expectedExpense || 0);
        return this.forecastRepo.save(this.forecastRepo.create(dto));
    }
    async updateForecast(id, dto) {
        const forecast = await this.forecastRepo.findOne({ where: { id } });
        if (!forecast)
            throw new common_1.NotFoundException('Forecast not found');
        Object.assign(forecast, dto);
        if (dto.expectedIncome !== undefined || dto.expectedExpense !== undefined) {
            forecast.expectedBalance = Number(forecast.expectedIncome) - Number(forecast.expectedExpense);
        }
        return this.forecastRepo.save(forecast);
    }
    async deleteForecast(id) {
        await this.forecastRepo.delete(id);
        return { deleted: true };
    }
    async findBudgetPlans() {
        return this.budgetRepo.find({ order: { startDate: 'DESC' } });
    }
    async createBudgetPlan(dto) {
        return this.budgetRepo.save(this.budgetRepo.create(dto));
    }
    async updateBudgetPlan(id, dto) {
        const plan = await this.budgetRepo.findOne({ where: { id } });
        if (!plan)
            throw new common_1.NotFoundException('Budget plan not found');
        Object.assign(plan, dto);
        return this.budgetRepo.save(plan);
    }
    async deleteBudgetPlan(id) {
        await this.budgetRepo.delete(id);
        return { deleted: true };
    }
    async getProfitLossReport(from, to) {
        const revenue = await this.txRepo.createQueryBuilder('t')
            .select('COALESCE(SUM(t.amount), 0)', 'total')
            .where('t.type = :type', { type: 'INCOME' })
            .andWhere('t.category = :cat', { cat: 'SALES' })
            .andWhere('t.transactionDate BETWEEN :from AND :to', { from, to })
            .getRawOne();
        const cogs = await this.txRepo.createQueryBuilder('t')
            .select('COALESCE(SUM(t.amount), 0)', 'total')
            .where('t.type = :type', { type: 'EXPENSE' })
            .andWhere('t.category = :cat', { cat: 'PURCHASE' })
            .andWhere('t.transactionDate BETWEEN :from AND :to', { from, to })
            .getRawOne();
        const opex = await this.txRepo.createQueryBuilder('t')
            .select('t.category', 'category')
            .addSelect('COALESCE(SUM(t.amount), 0)', 'total')
            .where('t.type = :type', { type: 'EXPENSE' })
            .andWhere('t.category != :purchase', { purchase: 'PURCHASE' })
            .andWhere('t.transactionDate BETWEEN :from AND :to', { from, to })
            .groupBy('t.category')
            .getRawMany();
        const totalRevenue = Number(revenue.total);
        const totalCOGS = Number(cogs.total);
        const grossProfit = totalRevenue - totalCOGS;
        const totalOpex = opex.reduce((sum, e) => sum + Number(e.total), 0);
        const netProfit = grossProfit - totalOpex;
        return {
            period: { from, to },
            totalRevenue,
            totalCOGS,
            grossProfit,
            operatingExpenses: opex,
            totalOperatingExpenses: totalOpex,
            netProfit,
            profitMargin: totalRevenue > 0 ? (netProfit / totalRevenue * 100).toFixed(2) + '%' : '0%',
        };
    }
};
exports.FinanceService = FinanceService;
exports.FinanceService = FinanceService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(entities_1.CashTransaction)),
    __param(1, (0, typeorm_1.InjectRepository)(entities_1.CashAccount)),
    __param(2, (0, typeorm_1.InjectRepository)(entities_1.DailyClosing)),
    __param(3, (0, typeorm_1.InjectRepository)(entities_1.BudgetPlan)),
    __param(4, (0, typeorm_1.InjectRepository)(entities_1.CashflowForecast)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository])
], FinanceService);
//# sourceMappingURL=finance.service.js.map