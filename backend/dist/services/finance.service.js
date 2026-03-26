"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.FinanceService = void 0;
const db_config_1 = require("../config/db.config");
const entities_1 = require("../finance/entities");
class FinanceService {
    constructor() {
        this.cashTxRepo = db_config_1.AppDataSource.getRepository(entities_1.CashTransaction);
        this.closingRepo = db_config_1.AppDataSource.getRepository(entities_1.DailyClosing);
        this.accountRepo = db_config_1.AppDataSource.getRepository(entities_1.CashAccount);
        this.forecastRepo = db_config_1.AppDataSource.getRepository(entities_1.CashflowForecast);
        this.budgetRepo = db_config_1.AppDataSource.getRepository(entities_1.BudgetPlan);
    }
    async getCashTransactions(page = 1, limit = 20) {
        const [items, total] = await this.cashTxRepo.findAndCount({
            skip: (page - 1) * limit, take: limit, order: { transactionDate: 'DESC' }
        });
        return { items, total, page, limit, totalPages: Math.ceil(total / limit) };
    }
    async createCashTransaction(dto) {
        if (!dto.transactionCode)
            dto.transactionCode = 'PT' + Date.now().toString().slice(-6);
        return this.cashTxRepo.save(this.cashTxRepo.create(dto));
    }
    async getCashFlowSummary(period) {
        return { income: 0, expense: 0, balance: 0, period };
    }
    async getProfitLoss(from, to) {
        return { revenue: 0, cogs: 0, grossProfit: 0, expenses: 0, netProfit: 0 };
    }
    async getDailyClosings(page = 1, limit = 20) {
        const [items, total] = await this.closingRepo.findAndCount({ skip: (page - 1) * limit, take: limit, order: { closingDate: 'DESC' } });
        return { items, total, page, limit };
    }
    async createDailyClosing(dto) {
        return this.closingRepo.save(this.closingRepo.create(dto));
    }
    async getCashAccounts() {
        return this.accountRepo.find();
    }
    async getForecasts() { return this.forecastRepo.find(); }
    async createForecast(dto) { return this.forecastRepo.save(this.forecastRepo.create(dto)); }
    async updateForecast(id, dto) {
        const record = await this.forecastRepo.findOne({ where: { id } });
        if (!record)
            throw new Error('Not found');
        Object.assign(record, dto);
        return this.forecastRepo.save(record);
    }
    async deleteForecast(id) {
        const record = await this.forecastRepo.findOne({ where: { id } });
        if (record)
            await this.forecastRepo.remove(record);
    }
    async getBudgetPlans() { return this.budgetRepo.find(); }
    async createBudgetPlan(dto) { return this.budgetRepo.save(this.budgetRepo.create(dto)); }
    async updateBudgetPlan(id, dto) {
        const record = await this.budgetRepo.findOne({ where: { id } });
        if (!record)
            throw new Error('Not found');
        Object.assign(record, dto);
        return this.budgetRepo.save(record);
    }
    async deleteBudgetPlan(id) {
        const record = await this.budgetRepo.findOne({ where: { id } });
        if (record)
            await this.budgetRepo.remove(record);
    }
}
exports.FinanceService = FinanceService;
//# sourceMappingURL=finance.service.js.map