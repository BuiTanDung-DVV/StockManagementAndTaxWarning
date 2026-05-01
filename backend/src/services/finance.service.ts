import { AppDataSource } from '../config/db.config';
import { CashTransaction, DailyClosing, CashAccount, CashflowForecast, BudgetPlan, Invoice, TaxObligation, PurchaseWithoutInvoice, PurchaseWithoutInvoiceItem } from '../finance/entities';
import { ActivityLog } from '../system/entities';

export class FinanceService {
    private cashTxRepo = AppDataSource.getRepository(CashTransaction);
    private closingRepo = AppDataSource.getRepository(DailyClosing);
    private accountRepo = AppDataSource.getRepository(CashAccount);
    private forecastRepo = AppDataSource.getRepository(CashflowForecast);
    private budgetRepo = AppDataSource.getRepository(BudgetPlan);
    private invoiceRepo = AppDataSource.getRepository(Invoice);

    private taxObRepo = AppDataSource.getRepository(TaxObligation);
    private purchaseNoInvRepo = AppDataSource.getRepository(PurchaseWithoutInvoice);
    private activityLogRepo = AppDataSource.getRepository(ActivityLog);

    private async logActivity(input: {
        userId?: number;
        action: string;
        entityType: string;
        entityId?: number;
        entityName?: string;
        oldValue?: string;
        newValue?: string;
        description?: string;
        ipAddress?: string;
    }) {
        if (!input.userId) return;
        const log = this.activityLogRepo.create({
            userId: input.userId,
            action: input.action,
            entityType: input.entityType,
            entityId: input.entityId,
            entityName: input.entityName,
            oldValue: input.oldValue,
            newValue: input.newValue,
            description: input.description,
            ipAddress: input.ipAddress,
        });
        await this.activityLogRepo.save(log);
    }

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

        // Doanh thu + Giá vốn thực tế từ sales_orders (COGS per-item)
        const salesResult = await AppDataSource.createQueryBuilder()
            .select("COALESCE(SUM(o.total_amount), 0)", 'revenue')
            .addSelect("COALESCE(SUM(o.total_cogs), 0)", 'cogs')
            .from('sales_orders', 'o')
            .where("o.order_date >= :fromDate AND o.order_date <= :toDate AND o.status != 'CANCELLED'", { fromDate, toDate })
            .getRawOne();

        // Chi phí vận hành (loại trừ PURCHASE vì đã tính trong COGS)
        const expenseResult = await this.cashTxRepo.createQueryBuilder('t')
            .select("COALESCE(SUM(CASE WHEN t.type = 'EXPENSE' AND t.category != 'PURCHASE' THEN t.amount ELSE 0 END), 0)", 'expenses')
            .where('t.transaction_date >= :fromDate AND t.transaction_date <= :toDate', { fromDate, toDate })
            .getRawOne();

        const revenue = Number(salesResult?.revenue || 0);
        const cogs = Number(salesResult?.cogs || 0);
        const operatingExpenses = Number(expenseResult?.expenses || 0);
        const grossProfit = revenue - cogs;
        const netProfit = grossProfit - operatingExpenses;
        const grossMarginPct = revenue > 0 ? Number(((grossProfit / revenue) * 100).toFixed(2)) : 0;
        const netMarginPct = revenue > 0 ? Number(((netProfit / revenue) * 100).toFixed(2)) : 0;
        return {
            revenue,
            cogs,
            grossProfit,
            expenses: operatingExpenses,
            operatingExpenses,
            netProfit,
            grossMarginPct,
            netMarginPct,
            from: fromDate,
            to: toDate,
        };
    }

    async getInvoiceReconciliation(from?: string, to?: string) {
        const fromDate = from ? new Date(from) : new Date(new Date().getFullYear(), new Date().getMonth(), 1);
        const toDate = to ? new Date(to) : new Date();
        toDate.setHours(23, 59, 59, 999);

        const rows = await this.invoiceRepo.createQueryBuilder('i')
            .select('i.invoice_type', 'invoiceType')
            .addSelect('COUNT(*)', 'count')
            .addSelect('COALESCE(SUM(i.total_amount), 0)', 'totalValue')
            .where('i.invoice_date >= :fromDate AND i.invoice_date <= :toDate', { fromDate, toDate })
            .groupBy('i.invoice_type')
            .getRawMany();

        const inRow = rows.find((r) => r.invoiceType === 'IN');
        const outRow = rows.find((r) => r.invoiceType === 'OUT');
        const inbound = {
            count: Number(inRow?.count || 0),
            totalValue: Number(inRow?.totalValue || 0),
        };
        const outbound = {
            count: Number(outRow?.count || 0),
            totalValue: Number(outRow?.totalValue || 0),
        };

        let recommendation = 'Dữ liệu hóa đơn cân đối.';
        let suspiciousPattern: string | null = null;
        if (inbound.totalValue > outbound.totalValue * 1.5) {
            suspiciousPattern = 'Đầu vào cao bất thường so với đầu ra';
            recommendation = 'Rà soát tồn kho thực tế và chứng từ đầu ra để tránh rủi ro tồn kho ảo.';
        } else if (outbound.totalValue > 0 && inbound.totalValue === 0) {
            suspiciousPattern = 'Có hóa đơn đầu ra nhưng không có đầu vào';
            recommendation = 'Bổ sung chứng từ đầu vào hợp lệ hoặc kiểm tra lại nghiệp vụ xuất hàng.';
        }

        return {
            from: fromDate,
            to: toDate,
            inbound,
            outbound,
            analysis: {
                inboundVsOutbound: inbound.totalValue <= outbound.totalValue ? 'Đầu vào <= Đầu ra' : 'Đầu vào > Đầu ra',
                suspiciousPattern,
                recommendation,
            },
        };
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
            relations: ['items'],
            skip: (page - 1) * limit,
            take: limit,
            order: { purchaseDate: 'DESC' },
        });
        const totalAmount = items.reduce((s, i) => s + Number(i.totalAmount), 0);
        return { items, total, totalAmount, page, limit, totalPages: Math.ceil(total / limit) };
    }

    async createPurchaseWithoutInvoice(dto: Partial<PurchaseWithoutInvoice> & {
        items?: Array<Partial<PurchaseWithoutInvoiceItem>>;
        creatorUserId?: number;
        creatorRole?: string;
        creatorAccountType?: string;
        requestIp?: string;
    }) {
        if (!dto.recordCode) dto.recordCode = 'BK-' + Date.now().toString().slice(-6);

        const sellerName = String(dto.sellerName || '').trim();
        const sellerIdentityNumber = String(dto.sellerIdentityNumber || '').trim();
        if (!sellerName) throw new Error('Validation: Tên người bán là bắt buộc');
        if (!sellerIdentityNumber) throw new Error('Validation: CCCD người bán là bắt buộc');

        const rawItems = Array.isArray(dto.items) ? dto.items : [];
        const items = rawItems
            .map((i) => {
                const productName = String(i.productName || '').trim();
                const productId = i.productId ? Number(i.productId) : undefined;
                const quantity = Number(i.quantity || 0);
                const unitPrice = Number(i.unitPrice || 0);
                const subtotal = Number(i.subtotal || (quantity * unitPrice));
                if (!productName || quantity <= 0 || unitPrice < 0 || subtotal < 0) return null;
                return { productName, productId, quantity, unitPrice, subtotal } as PurchaseWithoutInvoiceItem;
            })
            .filter((i): i is PurchaseWithoutInvoiceItem => !!i);

        if (items.length === 0) {
            throw new Error('Validation: Bảng kê phải có ít nhất 1 mặt hàng hợp lệ');
        }

        const computedTotal = items.reduce((sum, i) => sum + Number(i.subtotal), 0);
        const totalAmount = computedTotal > 0 ? computedTotal : Number(dto.totalAmount || 0);
        if (totalAmount <= 0) {
            throw new Error('Validation: Tổng tiền bảng kê phải lớn hơn 0');
        }

        const isOwner = dto.creatorAccountType === 'SHOP';
        const approvalStatus = isOwner ? 'APPROVED' : 'PENDING';
        const approvedBy = isOwner ? dto.creatorUserId : null;
        const approvedAt = isOwner ? new Date() : null;

        const entity = this.purchaseNoInvRepo.create({
            ...dto,
            sellerName,
            sellerIdentityNumber,
            totalAmount,
            items,
            createdBy: dto.creatorUserId,
            approvalStatus,
            approvedBy: approvedBy as any,
            approvedAt: approvedAt as any,
        });
        const saved = await this.purchaseNoInvRepo.save(entity);

        await this.logActivity({
            userId: dto.creatorUserId,
            action: 'CREATE',
            entityType: 'purchase_without_invoice',
            entityId: saved.id,
            entityName: saved.recordCode,
            newValue: JSON.stringify({ totalAmount: saved.totalAmount, approvalStatus: saved.approvalStatus }),
            description: isOwner
                ? 'Chủ shop tạo bảng kê và được duyệt tự động'
                : 'Nhân viên tạo bảng kê chờ duyệt',
            ipAddress: dto.requestIp,
        });

        return saved;
    }

    async updatePurchaseWithoutInvoiceApproval(
        id: number,
        input: {
            decision: 'APPROVED' | 'REJECTED';
            approvalNotes?: string;
            approverUserId?: number;
            approverAccountType?: string;
            requestIp?: string;
        },
    ) {
        const record = await this.purchaseNoInvRepo.findOne({ where: { id } });
        if (!record) throw new Error('Validation: Không tìm thấy bảng kê');

        if (input.approverAccountType !== 'SHOP') {
            throw new Error('Validation: Chỉ chủ shop mới có quyền duyệt bảng kê');
        }

        const oldValue = JSON.stringify({ approvalStatus: record.approvalStatus, approvalNotes: record.approvalNotes });
        record.approvalStatus = input.decision;
        record.approvalNotes = input.approvalNotes || null as any;
        record.approvedBy = input.approverUserId as any;
        record.approvedAt = new Date();

        const updated = await this.purchaseNoInvRepo.save(record);
        await this.logActivity({
            userId: input.approverUserId,
            action: input.decision === 'APPROVED' ? 'APPROVE' : 'REJECT',
            entityType: 'purchase_without_invoice',
            entityId: updated.id,
            entityName: updated.recordCode,
            oldValue,
            newValue: JSON.stringify({ approvalStatus: updated.approvalStatus, approvalNotes: updated.approvalNotes }),
            description: input.decision === 'APPROVED' ? 'Duyệt bảng kê mua hàng không hóa đơn' : 'Từ chối duyệt bảng kê mua hàng không hóa đơn',
            ipAddress: input.requestIp,
        });
        return updated;
    }
}
