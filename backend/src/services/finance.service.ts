import { AppDataSource } from '../config/db.config';
import { CashTransaction, DailyClosing, CashAccount, CashflowForecast, BudgetPlan, Invoice, TaxObligation, PurchaseWithoutInvoice, PurchaseWithoutInvoiceItem } from '../finance/entities';
import { JournalEntry, JournalLine } from '../finance/ledger.entity';
import { ActivityLog } from '../system/entities';
import { EntityManager } from 'typeorm';
import { InventoryService } from './inventory.service';
import { COGSService } from './cogs.service';
import { InventoryMovement, InventoryStock } from '../inventory/entities';
import { PostingService } from './posting.service';

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
    private postingService = new PostingService();

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
    async getCashTransactions(shopId: number, page = 1, limit = 20, type?: string, from?: string, to?: string) {
        const qb = this.cashTxRepo.createQueryBuilder('t')
            .where('t.shop_id = :shopId', { shopId });
        if (type) qb.andWhere('t.type = :type', { type });
        if (from) qb.andWhere('t.transaction_date >= :from', { from: new Date(from) });
        if (to) qb.andWhere('t.transaction_date <= :to', { to: new Date(to) });
        const [items, total] = await qb.orderBy('t.transaction_date', 'DESC')
            .skip((page - 1) * limit).take(limit).getManyAndCount();
        return { items, total, page, limit, totalPages: Math.ceil(total / limit) };
    }
    async createCashTransaction(shopId: number, dto: Partial<CashTransaction>, manager?: EntityManager) {
        const repo = manager ? manager.getRepository(CashTransaction) : this.cashTxRepo;
        if (!dto.transactionCode) dto.transactionCode = 'PT' + Date.now().toString().slice(-6);
        if (!dto.transactionDate) dto.transactionDate = new Date();
        const saved = await repo.save(repo.create({ ...dto, shopId }));

        // === Journal Ledger: Chỉ ghi bút toán cho các giao dịch độc lập (không liên kết với Sales/Purchase) ===
        const linkedRefTypes = ['SALES_ORDER', 'SALES_RETURN', 'PURCHASE_ORDER'];
        const refType = (dto as any).referenceType;
        if (!refType || !linkedRefTypes.includes(refType)) {
            const txType = dto.type || (dto as any).type;
            const amount = Number(dto.amount || 0);
            if (amount > 0) {
                const lines: { accountCode: string; amount: number; entryType: 'DEBIT' | 'CREDIT' }[] = [];
                if (txType === 'INCOME') {
                    // Thu nhập: Nợ TK 111 (Tiền mặt) / Có TK 511 (Doanh thu)
                    lines.push({ accountCode: '111', amount, entryType: 'DEBIT' });
                    lines.push({ accountCode: '511', amount, entryType: 'CREDIT' });
                } else if (txType === 'EXPENSE') {
                    // Chi phí: Nợ TK 642 (Chi phí) / Có TK 111 (Tiền mặt)
                    lines.push({ accountCode: '642', amount, entryType: 'DEBIT' });
                    lines.push({ accountCode: '111', amount, entryType: 'CREDIT' });
                }
                if (lines.length > 0) {
                    await this.postingService.postJournal(
                        shopId,
                        'CASH_TRANSACTION',
                        saved.id,
                        (dto as any).description || `Giao dịch ${txType === 'INCOME' ? 'thu' : 'chi'} tiền mặt`,
                        lines,
                        manager
                    );
                }
            }
        }



        return saved;
    }

    async updateCashTransaction(shopId: number, id: number, dto: Partial<CashTransaction>) {
        const tx = await this.cashTxRepo.findOne({ where: { id, shopId } });
        if (!tx) throw new Error('Cash transaction not found');
        Object.assign(tx, dto);
        return this.cashTxRepo.save(tx);
    }

    async deleteCashTransaction(shopId: number, id: number) {
        const tx = await this.cashTxRepo.findOne({ where: { id, shopId } });
        if (tx) await this.cashTxRepo.remove(tx);
        return { success: true };
    }

    async updateInvoice(shopId: number, id: number, dto: Partial<Invoice>) {
        const invoice = await this.invoiceRepo.findOne({ where: { id, shopId } });
        if (!invoice) throw new Error('Invoice not found');
        Object.assign(invoice, dto);
        return this.invoiceRepo.save(invoice);
    }

    async deleteInvoice(shopId: number, id: number) {
        const invoice = await this.invoiceRepo.findOne({ where: { id, shopId } });
        if (invoice) await this.invoiceRepo.remove(invoice);
        return { success: true };
    }

    async getCashFlowSummary(shopId: number, period?: string) {
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
            .where('t.shop_id = :shopId AND t.transaction_date >= :fromDate', { shopId, fromDate })
            .getRawOne();

        const income = Number(result?.income || 0);
        const expense = Number(result?.expense || 0);
        return { income, expense, balance: income - expense, period: period || 'month' };
    }

    async getProfitLoss(shopId: number, from?: string, to?: string) {
        const fromDate = from ? new Date(from) : new Date(new Date().getFullYear(), new Date().getMonth(), 1);
        const toDate = to ? new Date(to) : new Date();
        toDate.setHours(23, 59, 59, 999);

        const journalLineRepo = AppDataSource.getRepository(JournalLine);

        // Doanh thu (CREDIT 511 - Doanh thu bán hàng)
        const revenueResult = await journalLineRepo.createQueryBuilder('l')
            .innerJoin('l.journalEntry', 'e')
            .select("COALESCE(SUM(l.amount), 0)", 'revenue')
            .where("e.shop_id = :shopId AND e.entry_date >= :fromDate AND e.entry_date <= :toDate AND e.is_voided = false AND l.account_code = '511' AND l.entry_type = 'CREDIT'", { shopId, fromDate, toDate })
            .getRawOne();

        // Giá vốn (DEBIT 632 - Giá vốn hàng bán)
        const cogsResult = await journalLineRepo.createQueryBuilder('l')
            .innerJoin('l.journalEntry', 'e')
            .select("COALESCE(SUM(l.amount), 0)", 'cogs')
            .where("e.shop_id = :shopId AND e.entry_date >= :fromDate AND e.entry_date <= :toDate AND e.is_voided = false AND l.account_code = '632' AND l.entry_type = 'DEBIT'", { shopId, fromDate, toDate })
            .getRawOne();

        // Chi phí vận hành (DEBIT 642 - Chi phí quản lý kinh doanh)
        const expenseResult = await journalLineRepo.createQueryBuilder('l')
            .innerJoin('l.journalEntry', 'e')
            .select("COALESCE(SUM(l.amount), 0)", 'expenses')
            .where("e.shop_id = :shopId AND e.entry_date >= :fromDate AND e.entry_date <= :toDate AND e.is_voided = false AND l.account_code = '642' AND l.entry_type = 'DEBIT'", { shopId, fromDate, toDate })
            .getRawOne();

        const revenue = Number(revenueResult?.revenue || 0);
        const cogs = Number(cogsResult?.cogs || 0);
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

    async getInvoiceReconciliation(shopId: number, from?: string, to?: string) {
        const fromDate = from ? new Date(from) : new Date(new Date().getFullYear(), new Date().getMonth(), 1);
        const toDate = to ? new Date(to) : new Date();
        toDate.setHours(23, 59, 59, 999);

        const rows = await this.invoiceRepo.createQueryBuilder('i')
            .select('i.invoice_type', 'invoiceType')
            .addSelect('COUNT(*)', 'count')
            .addSelect('COALESCE(SUM(i.total_amount), 0)', 'totalValue')
            .where('i.shop_id = :shopId AND i.invoice_date >= :fromDate AND i.invoice_date <= :toDate', { shopId, fromDate, toDate })
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
    async getExpensesByCategory(shopId: number, from?: string, to?: string) {
        const fromDate = from ? new Date(from) : new Date(new Date().getFullYear(), new Date().getMonth(), 1);
        const toDate = to ? new Date(to) : new Date();
        toDate.setHours(23, 59, 59, 999);

        const rows = await this.cashTxRepo.createQueryBuilder('t')
            .select('t.category', 'category')
            .addSelect('SUM(t.amount)', 'amount')
            .addSelect('COUNT(*)', 'count')
            .where("t.shop_id = :shopId AND t.type = 'EXPENSE' AND t.transaction_date >= :fromDate AND t.transaction_date <= :toDate", { shopId, fromDate, toDate })
            .groupBy('t.category')
            .orderBy('SUM(t.amount)', 'DESC')
            .getRawMany();

        const categories = rows.map(r => ({ category: r.category, amount: Number(r.amount), count: Number(r.count) }));
        const total = categories.reduce((s, c) => s + c.amount, 0);

        // Recent expense transactions
        const [recentItems] = await this.cashTxRepo.findAndCount({
            where: { shopId, type: 'EXPENSE' },
            order: { transactionDate: 'DESC' },
            take: 10,
        });

        return { categories, total, recentItems };
    }

    // Daily Closings
    async getDailyClosings(shopId: number, page = 1, limit = 20) {
        const [items, total] = await this.closingRepo.findAndCount({ where: { shopId }, skip: (page - 1) * limit, take: limit, order: { closingDate: 'DESC' } });
        return { items, total, page, limit };
    }
    async getDailyClosingByDate(shopId: number, date: string) {
        const closing = await this.closingRepo.findOne({ where: { shopId, closingDate: new Date(date) as any } });
        if (!closing) {
            // Return today's summary from transactions
            const d = new Date(date);
            const summary = await this.cashTxRepo.createQueryBuilder('t')
                .select("COALESCE(SUM(CASE WHEN t.type = 'INCOME' AND (t.payment_method = 'CASH' OR t.payment_method IS NULL) THEN t.amount ELSE 0 END), 0)", 'cashIncome')
                .addSelect("COALESCE(SUM(CASE WHEN t.type = 'EXPENSE' AND (t.payment_method = 'CASH' OR t.payment_method IS NULL) THEN t.amount ELSE 0 END), 0)", 'cashExpense')
                .addSelect("COALESCE(SUM(CASE WHEN t.type = 'INCOME' AND t.payment_method != 'CASH' THEN t.amount ELSE 0 END), 0)", 'bankIncome')
                .addSelect("COALESCE(SUM(CASE WHEN t.type = 'EXPENSE' AND t.payment_method != 'CASH' THEN t.amount ELSE 0 END), 0)", 'bankExpense')
                .addSelect("COUNT(*)", 'orderCount')
                .where('t.shop_id = :shopId AND CAST(t.transaction_date AS DATE) = :d', { shopId, d: date })
                .getRawOne();

            const cashIncome = Number(summary?.cashIncome || 0);
            const cashExpense = Number(summary?.cashExpense || 0);
            const bankIncome = Number(summary?.bankIncome || 0);
            const bankExpense = Number(summary?.bankExpense || 0);
            const totalIncome = cashIncome + bankIncome;
            const totalExpense = cashExpense + bankExpense;

            // Find the most recent daily closing before this date to get openingCash
            const lastClosing = await this.closingRepo.createQueryBuilder('c')
                .where('c.shop_id = :shopId AND c.closing_date < :d', { shopId, d: date })
                .orderBy('c.closing_date', 'DESC')
                .getOne();
            
            const openingCash = lastClosing ? Number(lastClosing.closingCash) : 0;
            const expectedCash = openingCash + cashIncome - cashExpense;

            // Get recent transactions for the day
            const transactions = await this.cashTxRepo.find({
                where: { shopId, transactionDate: d as any },
                order: { createdAt: 'DESC' },
                take: 20,
            });

            return { 
                closingDate: date, 
                totalIncome, 
                totalExpense, 
                cashIncome,
                cashExpense,
                bankIncome,
                bankExpense,
                openingCash,
                expectedCash,
                netProfit: totalIncome - totalExpense, 
                orderCount: Number(summary?.orderCount || 0), 
                transactions, 
                closed: false 
            };
        }
        return { ...closing, closed: true };
    }
    async createDailyClosing(shopId: number, dto: Partial<DailyClosing>) {
        const cashDifference = Number(dto.cashDifference || 0);
        if (Math.abs(cashDifference) > 50000 && (!dto.notes || dto.notes.trim().length === 0)) {
            throw new Error('Chênh lệch két vượt quá 50,000đ. Vui lòng nhập lý do giải trình vào phần ghi chú.');
        }
        return this.closingRepo.save(this.closingRepo.create({ ...dto, shopId }));
    }

    // Cash Accounts
    async getCashAccounts(shopId: number) {
        return this.accountRepo.find({ where: { shopId } });
    }

    // Cashflow Forecasts
    async getForecasts(shopId: number) {
        const items = await this.forecastRepo.find({ where: { shopId }, order: { forecastDate: 'ASC' } });
        return Array.isArray(items) ? items : (items ? [items] : []);
    }
    async createForecast(shopId: number, dto: Partial<CashflowForecast>) { return this.forecastRepo.save(this.forecastRepo.create({ ...dto, shopId })); }
    async updateForecast(shopId: number, id: number, dto: Partial<CashflowForecast>) {
        const record = await this.forecastRepo.findOne({ where: { id, shopId } });
        if (!record) throw new Error('Not found');
        Object.assign(record, dto);
        return this.forecastRepo.save(record);
    }
    async deleteForecast(shopId: number, id: number) {
        const record = await this.forecastRepo.findOne({ where: { id, shopId } });
        if (record) await this.forecastRepo.remove(record);
    }

    // Budget Plans
    async getBudgetPlans(shopId: number) { return this.budgetRepo.find({ where: { shopId }, order: { startDate: 'DESC' } }); }
    async createBudgetPlan(shopId: number, dto: Partial<BudgetPlan>) { return this.budgetRepo.save(this.budgetRepo.create({ ...dto, shopId })); }
    async updateBudgetPlan(shopId: number, id: number, dto: Partial<BudgetPlan>) {
        const record = await this.budgetRepo.findOne({ where: { id, shopId } });
        if (!record) throw new Error('Not found');
        Object.assign(record, dto);
        return this.budgetRepo.save(record);
    }
    async deleteBudgetPlan(shopId: number, id: number) {
        const record = await this.budgetRepo.findOne({ where: { id, shopId } });
        if (record) await this.budgetRepo.remove(record);
    }

    // Invoices
    async getInvoices(shopId: number, page = 1, limit = 20, type?: string) {
        const qb = this.invoiceRepo.createQueryBuilder('i')
            .where('i.shop_id = :shopId', { shopId });
        if (type) qb.andWhere('i.invoice_type = :type', { type });
        const [items, total] = await qb.orderBy('i.invoice_date', 'DESC')
            .skip((page - 1) * limit).take(limit).getManyAndCount();
        return { items, total, page, limit, totalPages: Math.ceil(total / limit) };
    }
    async getInvoiceSummary(shopId: number, from?: string, to?: string) {
        const fromDate = from ? new Date(from) : new Date(new Date().getFullYear(), new Date().getMonth(), 1);
        const toDate = to ? new Date(to) : new Date();
        toDate.setHours(23, 59, 59, 999);

        const result = await this.invoiceRepo.createQueryBuilder('i')
            .select("COALESCE(SUM(CASE WHEN i.invoice_type = 'IN' THEN i.tax_amount ELSE 0 END), 0)", 'vatIn')
            .addSelect("COALESCE(SUM(CASE WHEN i.invoice_type = 'OUT' THEN i.tax_amount ELSE 0 END), 0)", 'vatOut')
            .where('i.shop_id = :shopId AND i.invoice_date >= :fromDate AND i.invoice_date <= :toDate', { shopId, fromDate, toDate })
            .getRawOne();

        const vatIn = Number(result?.vatIn || 0);
        const vatOut = Number(result?.vatOut || 0);
        return { vatIn, vatOut, vatOwed: vatOut - vatIn };
    }
    async getInvoiceById(shopId: number, id: number) {
        const invoice = await this.invoiceRepo.findOne({ where: { id, shopId } });
        if (!invoice) throw new Error('Invoice not found');
        return invoice;
    }
    async createInvoice(shopId: number, dto: Partial<Invoice> & { type?: string }) {
        if (!dto.invoiceNumber) dto.invoiceNumber = 'HD' + Date.now().toString().slice(-8);
        if (!dto.invoiceType && dto.type) dto.invoiceType = dto.type;
        return this.invoiceRepo.save(this.invoiceRepo.create({ ...dto, shopId }));
    }


    // Tax Obligations
    async getTaxObligations(shopId: number) {
        const items = await this.taxObRepo.find({ where: { shopId }, order: { period: 'DESC' } });
        const totalVat = items.reduce((s, i) => s + Number(i.vatDeclared), 0);
        const totalPit = items.reduce((s, i) => s + Number(i.pitDeclared), 0);
        const totalPaidVat = items.reduce((s, i) => s + Number(i.vatPaid), 0);
        const totalPaidPit = items.reduce((s, i) => s + Number(i.pitPaid), 0);
        return { items, totalVat, totalPit, totalPaidVat, totalPaidPit, totalOwed: (totalVat + totalPit) - (totalPaidVat + totalPaidPit) };
    }
    async createTaxObligation(shopId: number, dto: Partial<TaxObligation>) {
        return this.taxObRepo.save(this.taxObRepo.create({ ...this.normalizeTaxObligationDto(dto), shopId }));
    }
    async updateTaxObligation(shopId: number, id: number, dto: Partial<TaxObligation>) {
        const record = await this.taxObRepo.findOne({ where: { id, shopId } });
        if (!record) throw new Error('Tax obligation not found');
        Object.assign(record, this.normalizeTaxObligationDto(dto));
        return this.taxObRepo.save(record);
    }
    async deleteTaxObligation(shopId: number, id: number) {
        const record = await this.taxObRepo.findOne({ where: { id, shopId } });
        if (record) await this.taxObRepo.remove(record);
        return { success: true };
    }

    // Purchases Without Invoice
    async getPurchasesWithoutInvoice(shopId: number, page = 1, limit = 20) {
        const [items, total] = await this.purchaseNoInvRepo.findAndCount({
            where: { shopId },
            relations: ['items'],
            skip: (page - 1) * limit,
            take: limit,
            order: { purchaseDate: 'DESC' },
        });
        const totalAmount = items.reduce((s, i) => s + Number(i.totalAmount), 0);
        return { items, total, totalAmount, page, limit, totalPages: Math.ceil(total / limit) };
    }

    async createPurchaseWithoutInvoice(shopId: number, dto: Partial<PurchaseWithoutInvoice> & {
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
                return { productName, productId, quantity, unitPrice, subtotal, shopId } as PurchaseWithoutInvoiceItem;
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
            shopId,
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
        shopId: number,
        id: number,
        input: {
            decision: 'APPROVED' | 'REJECTED';
            approvalNotes?: string;
            approverUserId?: number;
            approverAccountType?: string;
            requestIp?: string;
        },
    ) {
        const record = await this.purchaseNoInvRepo.findOne({ where: { id, shopId } });
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

        if (input.decision === 'APPROVED') {
            const inventoryService = new InventoryService();
            const cogsService = new COGSService();

            // Lấy chi tiết items
            const fullRecord = await this.purchaseNoInvRepo.findOne({ where: { id: updated.id }, relations: ['items'] });
            if (fullRecord && fullRecord.items) {
                for (const item of fullRecord.items) {
                    if (item.productId && item.warehouseId) {
                        // 1. Tạo chuyển động kho IN (bằng cách cập nhật stock và ghi movement)
                        const movementRepo = AppDataSource.getRepository(InventoryMovement);
                        await movementRepo.save(movementRepo.create({
                            shopId,
                            productId: item.productId,
                            warehouseId: item.warehouseId,
                            movementType: 'IN',
                            quantity: item.quantity,
                            referenceType: 'PURCHASE_WITHOUT_INVOICE',
                            referenceId: updated.id,
                            notes: `Bảng kê 01: ${updated.recordCode}`
                        }));

                        // Tăng quantity trong inventory_stocks (dùng TypeORM)
                        const stockRepo = AppDataSource.getRepository(InventoryStock);
                        let stock = await stockRepo.findOne({ where: { shopId, productId: item.productId, warehouseId: item.warehouseId } as any });
                        if (!stock) {
                            stock = stockRepo.create({ shopId, productId: item.productId, warehouseId: item.warehouseId, quantity: 0, updatedAt: new Date() });
                        }
                        stock.quantity = Number(stock.quantity) + Number(item.quantity);
                        stock.updatedAt = new Date();
                        await stockRepo.save(stock);

                        // 2. Tạo lô hàng mới tính FIFO
                        await cogsService.addInventoryLot({
                            productId: item.productId,
                            quantity: item.quantity,
                            costPrice: item.unitPrice,
                            purchaseId: updated.id,
                            notes: `Bảng kê 01: ${updated.recordCode}`,
                            shopId
                        });
                    }
                }
            }

            // 3. Ghi nhận chi tiền vào Sổ cái
            await this.postingService.postJournal(
                shopId,
                'PURCHASE_WITHOUT_INVOICE',
                updated.id,
                `Chi mua hàng không hóa đơn: ${updated.recordCode}`,
                [
                    { accountCode: '156', amount: Number(updated.totalAmount), entryType: 'DEBIT' },
                    { accountCode: '111', amount: Number(updated.totalAmount), entryType: 'CREDIT' },
                ]
            );
        }

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

    private normalizeTaxObligationDto(dto: any) {
        const normalized = { ...dto };
        if (normalized.vatDeclared === undefined && normalized.vatAmount !== undefined) {
            normalized.vatDeclared = normalized.vatAmount;
        }
        if (normalized.pitDeclared === undefined && normalized.pitAmount !== undefined) {
            normalized.pitDeclared = normalized.pitAmount;
        }
        if (normalized.vatPaid === undefined && normalized.paidVatAmount !== undefined) {
            normalized.vatPaid = normalized.paidVatAmount;
        }
        if (normalized.pitPaid === undefined && normalized.paidPitAmount !== undefined) {
            normalized.pitPaid = normalized.paidPitAmount;
        }
        delete normalized.vatAmount;
        delete normalized.pitAmount;
        delete normalized.paidVatAmount;
        delete normalized.paidPitAmount;
        return normalized;
    }
}
