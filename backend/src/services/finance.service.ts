import { AppDataSource } from '../config/db.config';
import { CashTransaction, DailyClosing, CashAccount, CashflowForecast, BudgetPlan, Invoice, TaxObligation, PurchaseWithoutInvoice } from '../finance/entities';

export class FinanceService {
    private cashTxRepo = AppDataSource.getRepository(CashTransaction);
    private closingRepo = AppDataSource.getRepository(DailyClosing);
    private accountRepo = AppDataSource.getRepository(CashAccount);
    private forecastRepo = AppDataSource.getRepository(CashflowForecast);
    private budgetRepo = AppDataSource.getRepository(BudgetPlan);
    private invoiceRepo = AppDataSource.getRepository(Invoice);

    private taxObRepo = AppDataSource.getRepository(TaxObligation);
    private purchaseNoInvRepo = AppDataSource.getRepository(PurchaseWithoutInvoice);

    // Cash Transactions
    async getCashTransactions(page = 1, limit = 20, type?: string, from?: string, to?: string) {
        const qb = this.cashTxRepo.createQueryBuilder('t');
        if (type) qb.andWhere('t.type = :type', { type });
        if (from) qb.andWhere('t.transaction_date >= :from', { from: new Date(from) });
        if (to) qb.andWhere('t.transaction_date <= :to', { to: new Date(to) });
        const [items, total] = await qb.orderBy('t.transaction_date', 'DESC')
            .skip((page - 1) * limit).take(limit).getManyAndCount();
        return { items, total, page, limit, totalPages: Math.ceil(total / limit) };
    }
    async createCashTransaction(dto: Partial<CashTransaction>) {
        if (!dto.transactionCode) dto.transactionCode = 'PT' + Date.now().toString().slice(-6);
        return this.cashTxRepo.save(this.cashTxRepo.create(dto));
    }
    async getCashFlowSummary(period?: string) {
        const now = new Date();
        let fromDate: Date;
        switch (period) {
            case 'today': fromDate = new Date(now.getFullYear(), now.getMonth(), now.getDate()); break;
            case 'week': fromDate = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000); break;
            case 'year': fromDate = new Date(now.getFullYear(), 0, 1); break;
            default: fromDate = new Date(now.getFullYear(), now.getMonth(), 1); break;
        }

        const result = await this.cashTxRepo.createQueryBuilder('t')
            .select("COALESCE(SUM(CASE WHEN t.type = 'INCOME' THEN t.amount ELSE 0 END), 0)", 'income')
            .addSelect("COALESCE(SUM(CASE WHEN t.type = 'EXPENSE' THEN t.amount ELSE 0 END), 0)", 'expense')
            .where('t.transaction_date >= :fromDate', { fromDate })
            .getRawOne();

        const income = Number(result?.income || 0);
        const expense = Number(result?.expense || 0);
        return { income, expense, balance: income - expense, period: period || 'month' };
    }

    async getProfitLoss(from?: string, to?: string) {
        const fromDate = from ? new Date(from) : new Date(new Date().getFullYear(), new Date().getMonth(), 1);
        const toDate = to ? new Date(to) : new Date();
        toDate.setHours(23, 59, 59, 999);

        const result = await this.cashTxRepo.createQueryBuilder('t')
            .select("COALESCE(SUM(CASE WHEN t.type = 'INCOME' AND t.category = 'SALES' THEN t.amount ELSE 0 END), 0)", 'revenue')
            .addSelect("COALESCE(SUM(CASE WHEN t.type = 'EXPENSE' AND t.category = 'PURCHASE' THEN t.amount ELSE 0 END), 0)", 'cogs')
            .addSelect("COALESCE(SUM(CASE WHEN t.type = 'EXPENSE' AND t.category != 'PURCHASE' THEN t.amount ELSE 0 END), 0)", 'expenses')
            .where('t.transaction_date >= :fromDate AND t.transaction_date <= :toDate', { fromDate, toDate })
            .getRawOne();

        const revenue = Number(result?.revenue || 0);
        const cogs = Number(result?.cogs || 0);
        const expenses = Number(result?.expenses || 0);
        const grossProfit = revenue - cogs;
        return { revenue, cogs, grossProfit, expenses, netProfit: grossProfit - expenses, from: fromDate, to: toDate };
    }

    // Expenses by category
    async getExpensesByCategory(from?: string, to?: string) {
        const fromDate = from ? new Date(from) : new Date(new Date().getFullYear(), new Date().getMonth(), 1);
        const toDate = to ? new Date(to) : new Date();
        toDate.setHours(23, 59, 59, 999);

        const rows = await this.cashTxRepo.createQueryBuilder('t')
            .select('t.category', 'category')
            .addSelect('SUM(t.amount)', 'amount')
            .addSelect('COUNT(*)', 'count')
            .where("t.type = 'EXPENSE' AND t.transaction_date >= :fromDate AND t.transaction_date <= :toDate", { fromDate, toDate })
            .groupBy('t.category')
            .orderBy('SUM(t.amount)', 'DESC')
            .getRawMany();

        const categories = rows.map(r => ({ category: r.category, amount: Number(r.amount), count: Number(r.count) }));
        const total = categories.reduce((s, c) => s + c.amount, 0);

        // Recent expense transactions
        const [recentItems] = await this.cashTxRepo.findAndCount({
            where: { type: 'EXPENSE' },
            order: { transactionDate: 'DESC' },
            take: 10,
        });

        return { categories, total, recentItems };
    }

    // Daily Closings
    async getDailyClosings(page = 1, limit = 20) {
        const [items, total] = await this.closingRepo.findAndCount({ skip: (page - 1) * limit, take: limit, order: { closingDate: 'DESC' } });
        return { items, total, page, limit };
    }
    async getDailyClosingByDate(date: string) {
        const closing = await this.closingRepo.findOne({ where: { closingDate: new Date(date) as any } });
        if (!closing) {
            // Return today's summary from transactions
            const d = new Date(date);
            const summary = await this.cashTxRepo.createQueryBuilder('t')
                .select("COALESCE(SUM(CASE WHEN t.type = 'INCOME' THEN t.amount ELSE 0 END), 0)", 'totalIncome')
                .addSelect("COALESCE(SUM(CASE WHEN t.type = 'EXPENSE' THEN t.amount ELSE 0 END), 0)", 'totalExpense')
                .addSelect("COUNT(*)", 'orderCount')
                .where('CAST(t.transaction_date AS DATE) = :d', { d: date })
                .getRawOne();

            const totalIncome = Number(summary?.totalIncome || 0);
            const totalExpense = Number(summary?.totalExpense || 0);

            // Get recent transactions for the day
            const transactions = await this.cashTxRepo.find({
                where: { transactionDate: d as any },
                order: { createdAt: 'DESC' },
                take: 20,
            });

            return { closingDate: date, totalIncome, totalExpense, netProfit: totalIncome - totalExpense, orderCount: Number(summary?.orderCount || 0), transactions, closed: false };
        }
        return { ...closing, closed: true };
    }
    async createDailyClosing(dto: Partial<DailyClosing>) {
        return this.closingRepo.save(this.closingRepo.create(dto));
    }

    // Cash Accounts
    async getCashAccounts() {
        return this.accountRepo.find();
    }

    // Cashflow Forecasts
    async getForecasts() { return this.forecastRepo.find({ order: { forecastDate: 'ASC' } }); }
    async createForecast(dto: Partial<CashflowForecast>) { return this.forecastRepo.save(this.forecastRepo.create(dto)); }
    async updateForecast(id: number, dto: Partial<CashflowForecast>) {
        const record = await this.forecastRepo.findOne({ where: { id } });
        if (!record) throw new Error('Not found');
        Object.assign(record, dto);
        return this.forecastRepo.save(record);
    }
    async deleteForecast(id: number) {
        const record = await this.forecastRepo.findOne({ where: { id } });
        if (record) await this.forecastRepo.remove(record);
    }

    // Budget Plans
    async getBudgetPlans() { return this.budgetRepo.find({ order: { startDate: 'DESC' } }); }
    async createBudgetPlan(dto: Partial<BudgetPlan>) { return this.budgetRepo.save(this.budgetRepo.create(dto)); }
    async updateBudgetPlan(id: number, dto: Partial<BudgetPlan>) {
        const record = await this.budgetRepo.findOne({ where: { id } });
        if (!record) throw new Error('Not found');
        Object.assign(record, dto);
        return this.budgetRepo.save(record);
    }
    async deleteBudgetPlan(id: number) {
        const record = await this.budgetRepo.findOne({ where: { id } });
        if (record) await this.budgetRepo.remove(record);
    }

    // Invoices
    async getInvoices(page = 1, limit = 20, type?: string) {
        const qb = this.invoiceRepo.createQueryBuilder('i');
        if (type) qb.andWhere('i.invoice_type = :type', { type });
        const [items, total] = await qb.orderBy('i.invoice_date', 'DESC')
            .skip((page - 1) * limit).take(limit).getManyAndCount();
        return { items, total, page, limit, totalPages: Math.ceil(total / limit) };
    }
    async getInvoiceSummary(from?: string, to?: string) {
        const fromDate = from ? new Date(from) : new Date(new Date().getFullYear(), new Date().getMonth(), 1);
        const toDate = to ? new Date(to) : new Date();
        toDate.setHours(23, 59, 59, 999);

        const result = await this.invoiceRepo.createQueryBuilder('i')
            .select("COALESCE(SUM(CASE WHEN i.invoice_type = 'IN' THEN i.tax_amount ELSE 0 END), 0)", 'vatIn')
            .addSelect("COALESCE(SUM(CASE WHEN i.invoice_type = 'OUT' THEN i.tax_amount ELSE 0 END), 0)", 'vatOut')
            .where('i.invoice_date >= :fromDate AND i.invoice_date <= :toDate', { fromDate, toDate })
            .getRawOne();

        const vatIn = Number(result?.vatIn || 0);
        const vatOut = Number(result?.vatOut || 0);
        return { vatIn, vatOut, vatOwed: vatOut - vatIn };
    }
    async getInvoiceById(id: number) {
        const invoice = await this.invoiceRepo.findOne({ where: { id } });
        if (!invoice) throw new Error('Invoice not found');
        return invoice;
    }
    async createInvoice(dto: Partial<Invoice>) {
        if (!dto.invoiceNumber) dto.invoiceNumber = 'HD' + Date.now().toString().slice(-8);
        return this.invoiceRepo.save(this.invoiceRepo.create(dto));
    }


    // Tax Obligations
    async getTaxObligations() {
        const items = await this.taxObRepo.find({ order: { period: 'DESC' } });
        const totalVat = items.reduce((s, i) => s + Number(i.vatDeclared), 0);
        const totalPit = items.reduce((s, i) => s + Number(i.pitDeclared), 0);
        const totalPaidVat = items.reduce((s, i) => s + Number(i.vatPaid), 0);
        const totalPaidPit = items.reduce((s, i) => s + Number(i.pitPaid), 0);
        return { items, totalVat, totalPit, totalPaidVat, totalPaidPit, totalOwed: (totalVat + totalPit) - (totalPaidVat + totalPaidPit) };
    }
    async createTaxObligation(dto: Partial<TaxObligation>) {
        return this.taxObRepo.save(this.taxObRepo.create(dto));
    }

    // Purchases Without Invoice
    async getPurchasesWithoutInvoice(page = 1, limit = 20) {
        const [items, total] = await this.purchaseNoInvRepo.findAndCount({
            skip: (page - 1) * limit, take: limit, order: { purchaseDate: 'DESC' }
        });
        const totalAmount = items.reduce((s, i) => s + Number(i.totalAmount), 0);
        return { items, total, totalAmount, page, limit, totalPages: Math.ceil(total / limit) };
    }
    async createPurchaseWithoutInvoice(dto: Partial<PurchaseWithoutInvoice>) {
        if (!dto.recordCode) dto.recordCode = 'BK-' + Date.now().toString().slice(-6);
        return this.purchaseNoInvRepo.save(this.purchaseNoInvRepo.create(dto));
    }
}
