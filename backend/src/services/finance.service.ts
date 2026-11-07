import { buildCashflowProjection } from '../finance/cashflow-projection.utils';
import { readOpeningBalanceEffects, openingDebtEffectRows, openingEffectCents, openingEffectValue } from '../finance/opening-balance-effects.repository';
import { lockShopMutation } from '../utils/shop-mutation-lock';
import { assertPastOrToday } from '../utils/business-date';
import { AppDataSource } from '../config/db.config';
import { CashTransaction, DailyClosing, CashAccount, CashflowForecast, BudgetPlan, TaxObligation, PurchaseWithoutInvoice, PurchaseWithoutInvoiceItem } from '../finance/entities';
import { Invoice, InvoiceItem } from '../system/entities';
import { JournalEntry, JournalLine } from '../finance/ledger.entity';
import { ActivityLog } from '../system/entities';
import { Between, EntityManager, In, SelectQueryBuilder } from 'typeorm';
import { CashTransactionQueryInput, NormalizedCashTransactionQuery } from '../finance/finance-period.utils';
import { CashLedgerExportInputError, normalizeCashLedgerExportQuery, summarizeCashLedgerExport } from '../finance/cash-ledger-export.utils';
import { randomBytes } from 'crypto';
import { readDailyReturnValue } from '../finance/daily-return-value.repository';
import { SystemService } from './system.service';
import { COGSService } from './cogs.service';
import { InventoryMovement, InventoryStock, Warehouse } from '../inventory/entities';
import { Product } from '../product/entities';
import { PostingService } from './posting.service';
import { calculateNetAmount } from '../sales/sales-metric.utils';
import {
    calculateOutstandingTax,
    normalizeNonNegative,
} from '../tax/tax-policy';
import {
    buildVietnamPeriodKeys,
    normalizeCashTransactionQuery,
    resolveCurrentMonthExpensePeriod,
    resolveVietnamBusinessDayPeriod,
    vietnamDateKey,
} from '../finance/finance-period.utils';
import { normalizeCashflowForecastInput } from '../finance/cashflow-forecast.utils';
import {
    normalizeInvoiceInput,
    normalizeInvoiceItems,
} from '../finance/invoice-input.utils';
import {
    cashLedgerAccountCode,
    cashTransactionCounterAccountCode,
    normalizeCashTransactionInput,
} from '../finance/cash-transaction-input.utils';
import { normalizeBudgetPlanInput } from '../finance/budget-plan-input.utils';
import { normalizeInvoiceDataQuality } from '../finance/invoice-data-quality.utils';
import { normalizeInvoiceListQuery } from '../finance/invoice-query.utils';
import { normalizeDatabaseBusinessDate } from '../system/data-freshness.utils';

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
    async getCashTransactions(
        shopId: number | number[],
        page = 1,
        limit = 20,
        type?: string,
        from?: string,
        to?: string,
        category?: string,
    ) {
        const query = normalizeCashTransactionQuery({
            page,
            limit,
            type,
            category,
            from,
            to,
        });
        const qb = this.cashTransactionQuery(shopId, query);

        const totalRow = await qb.clone()
            .select('COALESCE(SUM(t.amount), 0)', 'filteredAmountTotal')
            .getRawOne();
        const [items, total] = await qb.orderBy('t.transaction_date', 'DESC')
            .addOrderBy('t.id', 'DESC')
            .skip((query.page - 1) * query.limit)
            .take(query.limit)
            .getManyAndCount();
        return {
            items,
            total,
            page: query.page,
            limit: query.limit,
            totalPages: Math.ceil(total / query.limit),
            filteredAmountTotal: Number(totalRow?.filteredAmountTotal || 0),
        };
    }

    private cashTransactionQuery(
        shopId: number | number[], query: NormalizedCashTransactionQuery,
    ): SelectQueryBuilder<CashTransaction> {
        const shopCondition = Array.isArray(shopId)
            ? 't.shop_id IN (:...shopIds)'
            : 't.shop_id = :shopId';
        const shopParams = Array.isArray(shopId) ? { shopIds: shopId } : { shopId };
        const qb = this.cashTxRepo.createQueryBuilder('t')
            .where(shopCondition, shopParams);
        if (query.type) qb.andWhere('t.type = :type', { type: query.type });
        if (query.category) {
            qb.andWhere('t.category = :category', { category: query.category });
        }
        if (query.fromDate) {
            qb.andWhere('t.transaction_date >= CAST(:from AS date)', {
                from: vietnamDateKey(query.fromDate),
            });
        }
        if (query.toDate) {
            qb.andWhere('t.transaction_date <= CAST(:to AS date)', {
                to: vietnamDateKey(query.toDate),
            });
        }

        return qb;
    }

    async exportCashTransactions(shopId: number, input: CashTransactionQueryInput) {
        if (!Number.isInteger(shopId) || shopId <= 0) {
            throw new CashLedgerExportInputError('Chọn một cửa hàng để xuất sổ.');
        }
        const query = normalizeCashLedgerExportQuery(input);
        const items = await this.cashTransactionQuery(shopId, query)
            .orderBy('t.transaction_date', 'DESC').addOrderBy('t.id', 'DESC').getMany();
        const summary = summarizeCashLedgerExport(items);
        return {
            shopId,
            period: { from: input.from, to: input.to, dateField: 'transactionDate' },
            filters: { type: query.type || null, category: query.category || null },
            items,
            summary,
        };
    }

    async getCashTransaction(shopId: number | number[], id: number) {
        if (!Number.isInteger(id) || id <= 0) {
            throw new Error('Cash transaction not found');
        }
        const shopCondition = Array.isArray(shopId)
            ? 't.shop_id IN (:...shopIds)'
            : 't.shop_id = :shopId';
        const shopParams = Array.isArray(shopId) ? { shopIds: shopId } : { shopId };
        const transaction = await this.cashTxRepo.createQueryBuilder('t')
            .where('t.id = :id', { id })
            .andWhere(shopCondition, shopParams)
            .getOne();
        if (!transaction) throw new Error('Cash transaction not found');
        return transaction;
    }

    async createCashTransaction(shopId: number, dto: Partial<CashTransaction>, manager?: EntityManager): Promise<CashTransaction> {
        if (!manager) {
            return AppDataSource.transaction(async transactionManager => {
                await lockShopMutation(transactionManager, shopId);
                return this.createCashTransaction(shopId, dto, transactionManager);
            });
        }
        const repo = manager ? manager.getRepository(CashTransaction) : this.cashTxRepo;
        const normalized = normalizeCashTransactionInput(dto as any);
        const safeDto: any = { ...dto, ...normalized, shopId };
        // The existing cash ledger reference column is limited to 20 characters.
        if (safeDto.referenceType === 'PURCHASE_WITHOUT_INVOICE') safeDto.referenceType = 'PURCHASE_NO_INVOICE';
        delete safeDto.id;
        delete safeDto.createdAt;
        delete safeDto.description;
        if (!safeDto.transactionCode) safeDto.transactionCode = 'PT' + Date.now().toString().slice(-6);
        const saved = await repo.save(repo.create(safeDto as Partial<CashTransaction>));

        // === Journal Ledger: Chỉ ghi bút toán cho các giao dịch độc lập (không liên kết với Sales/Purchase) ===
        const linkedRefTypes = ['SALES_ORDER', 'SALES_ORDER_CANCEL', 'SALES_RETURN', 'PURCHASE_ORDER', 'PURCHASE_WITHOUT_INVOICE', 'PURCHASE_NO_INVOICE', 'DEBT_COLLECTION', 'SUPPLIER_PAYMENT'];
        const refType = (dto as any).referenceType;
        if (!refType || !linkedRefTypes.includes(refType)) {
            const txType = normalized.type;
            const amount = normalized.amount;
            if (amount > 0) {
                const lines: { accountCode: string; amount: number; entryType: 'DEBIT' | 'CREDIT' }[] = [];
                const cashAccount = cashLedgerAccountCode(normalized.paymentMethod);
                const counterAccount = cashTransactionCounterAccountCode(
                    txType,
                    normalized.category,
                );
                if (txType === 'INCOME') {
                    // Tiền vào có thể là doanh thu, thu nhập khác, vốn góp hoặc tiền vay.
                    lines.push({ accountCode: cashAccount, amount, entryType: 'DEBIT' });
                    lines.push({ accountCode: counterAccount, amount, entryType: 'CREDIT' });
                } else if (txType === 'EXPENSE') {
                    // Chi phí: Nợ TK 642 (Chi phí) / Có TK 111 (Tiền mặt)
                    lines.push({ accountCode: counterAccount, amount, entryType: 'DEBIT' });
                    lines.push({ accountCode: cashAccount, amount, entryType: 'CREDIT' });
                }
                if (lines.length > 0) {
                    await this.postingService.postJournal(
                        shopId,
                        'CASH_TRANSACTION',
                        saved.id,
                        (dto as any).description || `Giao dịch ${txType === 'INCOME' ? 'thu' : 'chi'} tiền mặt`,
                        lines,
                        manager,
                        normalized.transactionDate,
                    );
                }
            }
        }



        return saved;
    }

    async updateCashTransaction(shopId: number, id: number, dto: Partial<CashTransaction>) {
        return AppDataSource.transaction(async manager => {
            await lockShopMutation(manager, shopId);
            const repo = manager.getRepository(CashTransaction);
            const tx = await repo.findOne({ where: { id, shopId } });
            if (!tx) throw new Error('Cash transaction not found');
            if (tx.referenceType && tx.referenceType !== 'CASH_TRANSACTION') {
                throw new Error('Validation: Linked transaction must be updated from its source document');
            }

            const normalized = normalizeCashTransactionInput(dto as any, tx);
            Object.assign(tx, normalized);
            const saved = await repo.save(tx);

            const journalRepo = manager.getRepository(JournalEntry);
            await journalRepo.update(
                { shopId, referenceType: 'CASH_TRANSACTION', referenceId: id },
                { isVoided: true },
            );
            const cashAccount = cashLedgerAccountCode(normalized.paymentMethod);
            const counterAccount = cashTransactionCounterAccountCode(
                normalized.type,
                normalized.category,
            );
            const lines = normalized.type === 'INCOME'
                ? [
                    { accountCode: cashAccount, amount: normalized.amount, entryType: 'DEBIT' as const },
                    { accountCode: counterAccount, amount: normalized.amount, entryType: 'CREDIT' as const },
                ]
                : [
                    { accountCode: counterAccount, amount: normalized.amount, entryType: 'DEBIT' as const },
                    { accountCode: cashAccount, amount: normalized.amount, entryType: 'CREDIT' as const },
                ];
            await this.postingService.postJournal(
                shopId,
                'CASH_TRANSACTION',
                id,
                normalized.notes || `Cập nhật giao dịch ${normalized.type === 'INCOME' ? 'thu' : 'chi'}`,
                lines,
                manager,
                normalized.transactionDate,
            );
            return saved;
        });
    }

    async deleteCashTransaction(shopId: number, id: number) {
        return AppDataSource.transaction(async manager => {
            await lockShopMutation(manager, shopId);
            const repo = manager.getRepository(CashTransaction);
            const tx = await repo.findOne({ where: { id, shopId } });
            if (!tx) return { success: true };
            if (tx.referenceType && tx.referenceType !== 'CASH_TRANSACTION') {
                throw new Error('Validation: Linked transaction must be deleted from its source document');
            }
            await manager.getRepository(JournalEntry).update(
                { shopId, referenceType: 'CASH_TRANSACTION', referenceId: id },
                { isVoided: true },
            );
            await repo.remove(tx);
            return { success: true };
        });
    }

    async updateInvoice(shopId: number, id: number, dto: Partial<Invoice>) {
        if (Object.prototype.hasOwnProperty.call(dto, 'referenceType') || Object.prototype.hasOwnProperty.call(dto, 'referenceId')) throw new Error('Validation: Invoice source reference is server-controlled');
        return AppDataSource.transaction(async manager => {
            await lockShopMutation(manager, shopId);
            const invoiceRepo = manager.getRepository(Invoice);
            const invoice = await invoiceRepo.findOne({
                where: { id, shopId },
                relations: ['items', 'items.product'],
            });
            if (!invoice) throw new Error('Invoice not found');
            if (invoice.referenceType && invoice.referenceId) {
                throw new Error('Validation: Linked invoice must be updated from its source document');
            }

            const hasItems = Object.prototype.hasOwnProperty.call(dto, 'items');
            const itemSummary = hasItems
                ? normalizeInvoiceItems((dto as any).items)
                : null;
            if (itemSummary) {
                await this.validateInvoiceItemProducts(
                    manager,
                    shopId,
                    itemSummary.items.map(item => item.productId),
                );
            }
            const normalized = normalizeInvoiceInput(
                itemSummary
                    ? { ...dto, subtotal: itemSummary.subtotal, taxAmount: itemSummary.taxAmount }
                    : dto,
                invoice,
            );
            const safeDto: any = { ...dto, ...normalized };
            delete safeDto.id;
            delete safeDto.shopId;
            delete safeDto.createdAt;
            delete safeDto.items;
            Object.assign(invoice, safeDto);

            if (itemSummary) {
                await manager.getRepository(InvoiceItem).delete({ invoice: { id } });
                invoice.items = itemSummary.items.map(item => manager.getRepository(InvoiceItem).create({
                    invoice,
                    productId: item.productId,
                    itemName: item.itemName,
                    unit: item.unit,
                    quantity: item.quantity,
                    unitPrice: item.unitPrice,
                    subtotal: item.subtotal,
                    taxRate: item.taxRate,
                    taxAmount: item.taxAmount,
                }));
            }
            return invoiceRepo.save(invoice);
        });
    }

    async deleteInvoice(shopId: number, id: number) {
        return AppDataSource.transaction(async manager => {
            await lockShopMutation(manager, shopId);
            const invoiceRepo = manager.getRepository(Invoice);
            const invoice = await invoiceRepo.findOne({ where: { id, shopId } });
            if (invoice?.referenceType && invoice.referenceId) {
                throw new Error('Validation: Linked invoice must be deleted from its source document');
            }
            if (!invoice) return { success: true };

            await manager.getRepository(InvoiceItem).delete({ invoice: { id } });
            await invoiceRepo.remove(invoice);
            return { success: true };
        });
    }

    async getCashFlowSummary(shopId: number | number[], period?: string, from?: string, to?: string) {
        const now = new Date();
        let fromDate: Date;
        let toDate: Date = new Date();
        if (from && to) {
            ({ fromDate, toDate } = resolveCurrentMonthExpensePeriod(from, to));
        } else {
            switch (period) {
                case 'today': fromDate = new Date(now.getFullYear(), now.getMonth(), now.getDate()); break;
                case 'week': fromDate = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000); break;
                case 'year': fromDate = new Date(now.getFullYear(), 0, 1); break;
                case '6_months': fromDate = new Date(now.getFullYear(), now.getMonth() - 5, 1); break;
                default: fromDate = new Date(now.getFullYear(), now.getMonth(), 1); break;
            }
            toDate.setHours(23, 59, 59, 999);
        }
        const fromDateKey = vietnamDateKey(fromDate);
        const toDateKey = vietnamDateKey(toDate);

        return AppDataSource.transaction('REPEATABLE READ', async manager => {
            await manager.query('SET TRANSACTION READ ONLY');
            const cashTxRepo = manager.getRepository(CashTransaction);
            const shopCondition = Array.isArray(shopId) ? 't.shop_id IN (:...shopIds)' : 't.shop_id = :shopId';
            const shopParams = Array.isArray(shopId) ? { shopIds: shopId } : { shopId };
            const result = await cashTxRepo.createQueryBuilder('t')
                .select("COALESCE(SUM(CASE WHEN t.type = 'INCOME' THEN t.amount ELSE 0 END), 0)", 'income')
                .addSelect("COALESCE(SUM(CASE WHEN t.type = 'EXPENSE' THEN t.amount ELSE 0 END), 0)", 'expense')
                .where(`${shopCondition} AND t.transaction_date >= CAST(:fromDateKey AS date) AND t.transaction_date <= CAST(:toDateKey AS date)`, { ...shopParams, fromDateKey, toDateKey })
                .getRawOne();
            const latestTransactionRow = await cashTxRepo.createQueryBuilder('t')
                .select('MAX(t.transaction_date)', 'latestTransactionDate')
                .where(`${shopCondition} AND t.transaction_date <= CAST(:toDateKey AS date)`, {
                    ...shopParams,
                    toDateKey,
                })
                .getRawOne();

            const diffDays = Math.ceil((toDate.getTime() - fromDate.getTime()) / (1000 * 3600 * 24));
            const isMonthFormat = diffDays > 60;
            const dateFormat = isMonthFormat ? 'YYYY-MM' : 'YYYY-MM-DD';

            const transactionDateBucket = `TO_CHAR(t.transaction_date, '${dateFormat}')`;
            const dailyFlowRaw = await cashTxRepo.createQueryBuilder('t')
                .select(transactionDateBucket, 'date')
                .addSelect("COALESCE(SUM(CASE WHEN t.type = 'INCOME' THEN t.amount ELSE 0 END), 0)", 'income')
                .addSelect("COALESCE(SUM(CASE WHEN t.type = 'EXPENSE' THEN t.amount ELSE 0 END), 0)", 'expense')
                .where(`${shopCondition} AND t.transaction_date >= CAST(:fromDateKey AS date) AND t.transaction_date <= CAST(:toDateKey AS date)`, { ...shopParams, fromDateKey, toDateKey })
                .groupBy(transactionDateBucket)
                .orderBy(transactionDateBucket, 'ASC')
                .getRawMany();

            const dailyMap = new Map();
            dailyFlowRaw.forEach(d => {
                dailyMap.set(d.date, {
                    income: Number(d.income || 0),
                    expense: Number(d.expense || 0)
                });
            });

            const dailyFlow = buildVietnamPeriodKeys(
                fromDate,
                toDate,
                isMonthFormat ? 'month' : 'day',
            ).map((date) => ({
                date,
                income: dailyMap.get(date)?.income || 0,
                expense: dailyMap.get(date)?.expense || 0,
            }));

            const income = Number(result?.income || 0);
            const expense = Number(result?.expense || 0);
            const cashResult = await cashTxRepo.createQueryBuilder('t')
                .select("COALESCE(SUM(CASE WHEN t.type = 'INCOME' THEN t.amount ELSE -t.amount END), 0)", 'cashBalance')
                .where(`${shopCondition} AND t.transaction_date <= CAST(:toDateKey AS date) AND (t.payment_method = 'CASH' OR t.payment_method IS NULL)`, { ...shopParams, toDateKey })
                .getRawOne();
            let cashBalanceCents = openingEffectCents(cashResult?.cashBalance || 0);
            for (const selectedShopId of new Set(Array.isArray(shopId) ? shopId : [shopId])) {
                const effects = await readOpeningBalanceEffects(manager, {
                    shopId: selectedShopId,
                    asOf: toDateKey,
                    receivableIds: [],
                    payableIds: [],
                });
                // Opening cash changes the balance, never income/expense or the flow chart.
                cashBalanceCents += effects.cashCents;
            }
            const netCashFlow = calculateNetAmount(income, expense);
            return {
                income,
                expense,
                netCashFlow,
                balance: netCashFlow,
                cashBalance: openingEffectValue(cashBalanceCents),
                latestTransactionDate: normalizeDatabaseBusinessDate(
                    latestTransactionRow?.latestTransactionDate,
                ),
                period: { name: period || 'custom', from: fromDate, to: toDate },
                scope: Array.isArray(shopId) ? 'ALL_SHOPS' : 'SHOP',
                dailyFlow,
            };
        });
    }

    async getProfitLoss(shopId: number, from?: string, to?: string) {
        const { fromDate, toDate } = resolveCurrentMonthExpensePeriod(from, to);

        const journalLineRepo = AppDataSource.getRepository(JournalLine);

        // Doanh thu (CREDIT 511 - Doanh thu bán hàng)
        const revenueResult = await journalLineRepo.createQueryBuilder('l')
            .innerJoin('l.journalEntry', 'e')
            .select("COALESCE(SUM(CASE WHEN l.entry_type = 'CREDIT' THEN l.amount ELSE -l.amount END), 0)", 'revenue')
            .where("e.shop_id = :shopId AND e.entry_date >= :fromDate AND e.entry_date <= :toDate AND e.is_voided = false AND l.account_code = '511'", { shopId, fromDate, toDate })
            .getRawOne();

        // Giá vốn (DEBIT 632 - Giá vốn hàng bán)
        const cogsResult = await journalLineRepo.createQueryBuilder('l')
            .innerJoin('l.journalEntry', 'e')
            .select("COALESCE(SUM(CASE WHEN l.entry_type = 'DEBIT' THEN l.amount ELSE -l.amount END), 0)", 'cogs')
            .where("e.shop_id = :shopId AND e.entry_date >= :fromDate AND e.entry_date <= :toDate AND e.is_voided = false AND l.account_code = '632'", { shopId, fromDate, toDate })
            .getRawOne();

        // Chi phí vận hành (DEBIT 642 - Chi phí quản lý kinh doanh)
        const expenseEntries = await journalLineRepo.createQueryBuilder('l')
            .innerJoin('l.journalEntry', 'e')
            .select('l.id', 'id')
            .addSelect('e.entry_date', 'date')
            .addSelect('e.description', 'description')
            .addSelect("CASE WHEN l.entry_type = 'DEBIT' THEN l.amount ELSE -l.amount END", 'amount')
            .where("e.shop_id = :shopId AND e.entry_date >= :fromDate AND e.entry_date <= :toDate AND e.is_voided = false AND l.account_code = '642'", { shopId, fromDate, toDate })
            .orderBy('e.entry_date', 'DESC')
            .addOrderBy('l.id', 'DESC')
            .getRawMany();

        const revenue = Number(revenueResult?.revenue || 0);
        const cogs = Number(cogsResult?.cogs || 0);
        const operatingExpenseEntries = expenseEntries.map(row => ({ ...row, amount: Number(row.amount) }));
        const operatingExpenses = operatingExpenseEntries.reduce((sum, row) => sum + row.amount, 0);
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
            operatingExpenseEntries,
            netProfit,
            grossMarginPct,
            netMarginPct,
            from: fromDate,
            to: toDate,
        };
    }

    async getInvoiceReconciliation(
        shopId: number,
        from?: string,
        to?: string,
        scope?: string,
    ) {
        const normalizedScope = String(scope || 'PERIOD').toUpperCase();
        if (!['PERIOD', 'ALL'].includes(normalizedScope)) {
            throw new Error('Validation: Phạm vi đối chiếu hóa đơn không hợp lệ');
        }
        const period = normalizedScope === 'ALL'
            ? null
            : resolveCurrentMonthExpensePeriod(from, to);

        const totalsQuery = this.invoiceRepo.createQueryBuilder('i')
            .select('i.invoice_type', 'invoiceType')
            .addSelect('COUNT(*)', 'count')
            .addSelect('COALESCE(SUM(i.total_amount), 0)', 'totalValue')
            .where('i.shop_id = :shopId', { shopId });
        if (period) {
            totalsQuery.andWhere(
                'i.invoice_date >= :fromDate AND i.invoice_date <= :toDate',
                period,
            );
        }
        const rows = await totalsQuery.groupBy('i.invoice_type').getRawMany();

        const qualityQuery = this.invoiceRepo.createQueryBuilder('i')
            .leftJoin('i.items', 'item')
            .select('COUNT(DISTINCT i.id)', 'checkedInvoices')
            .addSelect('MIN(i.invoice_date)', 'firstInvoiceDate')
            .addSelect('MAX(i.invoice_date)', 'lastInvoiceDate')
            .addSelect(
                'COUNT(DISTINCT CASE WHEN item.id IS NULL THEN i.id END)',
                'missingItemInvoices',
            )
            .addSelect(
                `COUNT(DISTINCT CASE
                    WHEN ABS(i.total_amount - (
                        i.subtotal - COALESCE(i.discount_amount, 0) + i.tax_amount
                    )) > 0.01
                    THEN i.id END)`,
                'headerTotalMismatchInvoices',
            )
            .addSelect(
                `COUNT(DISTINCT CASE
                    WHEN item.id IS NOT NULL
                     AND ABS(i.subtotal - (
                        SELECT COALESCE(SUM(detail.subtotal), 0)
                        FROM invoice_items detail
                        WHERE detail.invoice_id = i.id
                     )) > 0.01
                    THEN i.id END)`,
                'headerSubtotalMismatchInvoices',
            )
            .addSelect(
                `COUNT(DISTINCT CASE
                    WHEN item.id IS NOT NULL
                     AND i.reference_type = 'SALES_ORDER'
                     AND EXISTS (
                        SELECT 1
                        FROM sales_orders source_order
                        WHERE source_order.id = i.reference_id
                          AND source_order.shop_id = i.shop_id
                          AND ABS(
                              COALESCE(i.discount_amount, 0)
                              - source_order.discount_amount
                          ) > 0.01
                     )
                    THEN i.id END)`,
                'unallocatedDiscountInvoices',
            )
            .addSelect(
                `COUNT(DISTINCT CASE
                    WHEN item.id IS NOT NULL
                     AND ABS(i.tax_amount - (
                        SELECT COALESCE(SUM(detail.tax_amount), 0)
                        FROM invoice_items detail
                        WHERE detail.invoice_id = i.id
                     )) > 0.01
                    THEN i.id END)`,
                'headerTaxMismatchInvoices',
            )
            .addSelect(
                `COALESCE(SUM(CASE
                    WHEN item.id IS NOT NULL AND item.quantity <= 0 THEN 1 ELSE 0 END), 0)`,
                'invalidLineItems',
            )
            .addSelect(
                `COALESCE(SUM(CASE
                    WHEN item.id IS NOT NULL
                     AND ABS(item.subtotal - (item.quantity * item.unit_price)) > 0.01
                    THEN 1 ELSE 0 END), 0)`,
                'lineSubtotalMismatchItems',
            )
            .addSelect(
                `COALESCE(SUM(CASE
                    WHEN item.id IS NOT NULL
                     AND ABS(item.tax_amount - (item.subtotal * item.tax_rate / 100)) > 0.01
                    THEN 1 ELSE 0 END), 0)`,
                'lineTaxMismatchItems',
            )
            .where('i.shop_id = :shopId', { shopId });
        if (period) {
            qualityQuery.andWhere(
                'i.invoice_date >= :fromDate AND i.invoice_date <= :toDate',
                period,
            );
        }
        const qualityRow = await qualityQuery.getRawOne();
        const quality = normalizeInvoiceDataQuality(qualityRow);

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
            scope: normalizedScope,
            from: period?.fromDate || quality.firstInvoiceDate,
            to: period?.toDate || quality.lastInvoiceDate,
            inbound,
            outbound,
            quality,
            analysis: {
                inboundVsOutbound: inbound.totalValue <= outbound.totalValue ? 'Đầu vào <= Đầu ra' : 'Đầu vào > Đầu ra',
                suspiciousPattern,
                recommendation,
            },
        };
    }

    // Expenses by category
    async getExpensesByCategory(shopId: number | number[], from?: string, to?: string) {
        const { fromDate, toDate } = resolveCurrentMonthExpensePeriod(from, to);
        const fromDateKey = vietnamDateKey(fromDate);
        const toDateKey = vietnamDateKey(toDate);
        const shopCondition = Array.isArray(shopId)
            ? 't.shop_id IN (:...shopIds)'
            : 't.shop_id = :shopId';
        const shopParams = Array.isArray(shopId) ? { shopIds: shopId } : { shopId };

        const rows = await this.cashTxRepo.createQueryBuilder('t')
            .select('t.category', 'category')
            .addSelect('SUM(t.amount)', 'amount')
            .addSelect('COUNT(*)', 'count')
            .where(`${shopCondition} AND t.type = 'EXPENSE' AND t.transaction_date >= CAST(:fromDateKey AS date) AND t.transaction_date <= CAST(:toDateKey AS date)`, { ...shopParams, fromDateKey, toDateKey })
            .groupBy('t.category')
            .orderBy('SUM(t.amount)', 'DESC')
            .getRawMany();

        const categories = rows.map(r => ({ category: r.category, amount: Number(r.amount), count: Number(r.count) }));
        const total = categories.reduce((s, c) => s + c.amount, 0);

        // Recent expense transactions
        const [recentItems] = await this.cashTxRepo.findAndCount({
            where: {
                shopId: Array.isArray(shopId) ? In(shopId) : shopId,
                type: 'EXPENSE',
                transactionDate: Between(fromDateKey as any, toDateKey as any),
            },
            order: { transactionDate: 'DESC' },
            take: 10,
        });

        return { categories, total, recentItems };
    }

    // Daily Closings
    async getDailyClosings(shopId: number, page = 1, limit = 20) {
        const [items, total] = await this.closingRepo.findAndCount({ where: { shopId }, skip: (page - 1) * limit, take: limit, order: { closingDate: 'DESC' } });
        return {
            items,
            total,
            page,
            limit,
            totalPages: Math.ceil(total / limit),
        };
    }
    async getDailyClosingByDate(shopId: number, date: string) {
        return AppDataSource.transaction('REPEATABLE READ', async manager => {
            await manager.query('SET TRANSACTION READ ONLY');
            return this.readDailyClosing(manager, shopId, date);
        });
    }

    private async readDailyClosing(manager: EntityManager, shopId: number, date: string) {
        const closingRepo = manager.getRepository(DailyClosing);
        const cashTxRepo = manager.getRepository(CashTransaction);
        const { businessDate, fromDate, toDate } = resolveVietnamBusinessDayPeriod(date);
        const explanationThreshold = await this.getClosingExplanationThreshold(shopId, manager);
        const closing = await closingRepo.findOne({
            where: { shopId, closingDate: businessDate as any },
        });
        if (!closing) {
            const summary = await cashTxRepo.createQueryBuilder('t')
                .select("COALESCE(SUM(CASE WHEN t.type = 'INCOME' AND (t.payment_method = 'CASH' OR t.payment_method IS NULL) THEN t.amount ELSE 0 END), 0)", 'cashIncome')
                .addSelect("COALESCE(SUM(CASE WHEN t.type = 'EXPENSE' AND (t.payment_method = 'CASH' OR t.payment_method IS NULL) THEN t.amount ELSE 0 END), 0)", 'cashExpense')
                .addSelect("COALESCE(SUM(CASE WHEN t.type = 'INCOME' AND t.payment_method != 'CASH' THEN t.amount ELSE 0 END), 0)", 'bankIncome')
                .addSelect("COALESCE(SUM(CASE WHEN t.type = 'EXPENSE' AND t.payment_method != 'CASH' THEN t.amount ELSE 0 END), 0)", 'bankExpense')
                .addSelect("COUNT(*)", 'transactionCount')
                .where('t.shop_id = :shopId AND t.transaction_date = CAST(:businessDate AS date)', { shopId, businessDate })
                .getRawOne();

            const salesRows = await manager.query(`
                SELECT
                    COUNT(*)::int AS "orderCount",
                    COALESCE(SUM(total_amount), 0) AS "totalSales"
                FROM sales_orders
                WHERE shop_id = $1
                  AND order_date >= $2
                  AND order_date <= $3
                  AND UPPER(COALESCE(status, '')) != 'CANCELLED'
            `, [shopId, fromDate, toDate]);
            const totalReturns = await readDailyReturnValue(manager, shopId, fromDate, toDate);

            const cashIncome = Number(summary?.cashIncome || 0);
            const cashExpense = Number(summary?.cashExpense || 0);
            const bankIncome = Number(summary?.bankIncome || 0);
            const bankExpense = Number(summary?.bankExpense || 0);
            const totalIncome = cashIncome + bankIncome;
            const totalExpense = cashExpense + bankExpense;

            // Find the most recent daily closing before this date to get openingCash
            const lastClosing = await closingRepo.createQueryBuilder('c')
                .where('c.shop_id = :shopId AND c.closing_date < :d', { shopId, d: businessDate })
                .orderBy('c.closing_date', 'DESC')
                .getOne();
            
            const carriedCashQuery = cashTxRepo.createQueryBuilder('t')
                .select("COALESCE(SUM(CASE WHEN t.type = 'INCOME' THEN t.amount WHEN t.type = 'EXPENSE' THEN -t.amount ELSE 0 END), 0)", 'carriedCash')
                .where('t.shop_id = :shopId AND t.transaction_date < CAST(:beforeDate AS date) AND (t.payment_method = \'CASH\' OR t.payment_method IS NULL)', {
                    shopId,
                    beforeDate: businessDate,
                });
            if (lastClosing) {
                carriedCashQuery.andWhere('t.transaction_date > CAST(:lastClosingDate AS date)', {
                    lastClosingDate: lastClosing.closingDate,
                });
            }
            const carriedCash = await carriedCashQuery.getRawOne();
            const effects = await readOpeningBalanceEffects(manager, {
                shopId, asOf: businessDate, receivableIds: [], payableIds: [],
            });
            // A closing already includes all offsets effective on its date.
            const anchorEffects = lastClosing ? await readOpeningBalanceEffects(manager, {
                shopId, asOf: normalizeDatabaseBusinessDate(lastClosing.closingDate)!,
                receivableIds: [], payableIds: [],
            }) : undefined;
            const openingCents = openingEffectCents(lastClosing?.closingCash || 0)
                + openingEffectCents(carriedCash?.carriedCash || 0)
                + effects.cashCents - (anchorEffects?.cashCents ?? 0n);
            const openingCash = openingEffectValue(openingCents);
            const expectedCash = openingEffectValue(openingCents
                + openingEffectCents(summary?.cashIncome || 0)
                - openingEffectCents(summary?.cashExpense || 0));

            // Get recent transactions for the day
            const transactions = await cashTxRepo.find({
                where: { shopId, transactionDate: businessDate as any },
                order: { createdAt: 'DESC' },
                take: 20,
            });

            const orderCount = Number(salesRows[0]?.orderCount || 0);
            const totalSales = Number(salesRows[0]?.totalSales || 0);

            return { 
                closingDate: businessDate,
                totalIncome, 
                totalExpense, 
                totalSales,
                totalReturns,
                cashIncome,
                cashExpense,
                bankIncome,
                bankExpense,
                openingCash,
                expectedCash,
                netProfit: totalIncome - totalExpense, 
                orderCount,
                transactionCount: Number(summary?.transactionCount || 0),
                transactions, 
                explanationThreshold,
                closed: false 
            };
        }
        return { ...closing, explanationThreshold, closed: true };
    }
    async createDailyClosing(shopId: number, dto: Partial<DailyClosing>) {
        assertPastOrToday(dto.closingDate || new Date(), 'Ngày chốt sổ');
        const { businessDate } = resolveVietnamBusinessDayPeriod(
            dto.closingDate?.toString(),
        );
        return AppDataSource.transaction(async manager => {
            await lockShopMutation(manager, shopId);
            const current = await this.readDailyClosing(manager, shopId, businessDate);
            if (current.closed) {
                throw new Error('Validation: Daily closing already exists');
            }
            let closingCents: bigint;
            try {
                if (typeof dto.closingCash !== 'number' && typeof dto.closingCash !== 'string') throw new Error();
                closingCents = openingEffectCents(dto.closingCash);
                if (closingCents < 0n || closingCents > 999999999999999999n) throw new Error();
            } catch {
                throw new Error('Validation: Nhập tiền mặt thực tế không âm, tối đa hai chữ số thập phân.');
            }
            const closingCash = openingEffectValue(closingCents);
            const cashDifference = openingEffectValue(closingCents - openingEffectCents(current.expectedCash || 0));
            const explanationThreshold = Number(current.explanationThreshold);
            if (Math.abs(cashDifference) > explanationThreshold && (!dto.notes || dto.notes.trim().length === 0)) {
                throw new Error(`Validation: Chênh lệch két vượt ngưỡng ${explanationThreshold.toLocaleString('vi-VN')}đ. Vui lòng nhập lý do giải trình.`);
            }
            const closingRepo = manager.getRepository(DailyClosing);
            const accountRepo = manager.getRepository(CashAccount);
            const closing = await closingRepo.save(closingRepo.create({
                closingDate: businessDate as any,
                openingCash: Number(current.openingCash || 0),
                closingCash,
                expectedCash: Number(current.expectedCash || 0),
                cashDifference,
                totalSales: Number(current.totalSales || 0),
                totalReturns: Number(current.totalReturns || 0),
                totalIncome: Number(current.totalIncome || 0),
                totalExpense: Number(current.totalExpense || 0),
                orderCount: Number(current.orderCount || 0),
                notes: dto.notes?.trim(),
                closedBy: dto.closedBy,
                closedAt: new Date(),
                shopId,
            }));

            if (cashDifference !== 0) {
                const targetAccount = await accountRepo.findOne({
                    where: { shopId, accountType: 'CASH', isActive: true },
                    lock: { mode: 'pessimistic_write' },
                });
                if (!targetAccount) {
                    throw new Error(
                        'Validation: Cửa hàng chưa có tài khoản tiền mặt đang hoạt động để ghi nhận chênh lệch chốt ngày',
                    );
                }
                const isSurplus = cashDifference > 0;
                const adjustAmount = Math.abs(cashDifference);
                const txCode = (isSurplus ? 'PT-ADJ-' : 'PC-ADJ-') + randomBytes(6).toString('hex');

                const txDto: Partial<CashTransaction> = {
                    transactionCode: txCode,
                    type: isSurplus ? 'INCOME' : 'EXPENSE',
                    category: 'OTHER',
                    amount: adjustAmount,
                    paymentMethod: 'CASH',
                    account: targetAccount,
                    counterparty: 'Hệ thống (Kiểm quỹ)',
                    transactionDate: businessDate as any,
                    notes: `Điều chỉnh chênh lệch chốt ca ngày ${businessDate}. Lý do: ${dto.notes || 'Không ghi chú'}`,
                    referenceType: 'DAILY_CLOSING',
                    referenceId: closing.id,
                };

                await this.createCashTransaction(shopId, txDto, manager);

                targetAccount.balance = Number(targetAccount.balance || 0) + cashDifference;
                await accountRepo.save(targetAccount);
            }

            return closing;
        });
    }

    private async getClosingExplanationThreshold(shopId: number, manager: EntityManager): Promise<number> {
        const rows = await manager.query(`SELECT config_value FROM system_configs
            WHERE (shop_id=$1 OR shop_id IS NULL) AND config_key=$2
            ORDER BY shop_id DESC NULLS LAST LIMIT 1`, [shopId, 'DAILY_CLOSING_EXPLANATION_THRESHOLD']);
        if (!rows.length) throw new Error('Thiếu cấu hình DAILY_CLOSING_EXPLANATION_THRESHOLD trong DB');
        const value = Number(rows[0].config_value);
        if (!Number.isFinite(value) || value < 0) {
            throw new Error('Cấu hình DAILY_CLOSING_EXPLANATION_THRESHOLD trong DB không hợp lệ');
        }
        return value;
    }

    // Cash Accounts
    async getCashAccounts(shopId: number) {
        return this.accountRepo.find({ where: { shopId } });
    }

    // Cashflow Forecasts
    async getCashflowProjection(shopId: number, days = 30, now = new Date()) {
        if (!Number.isInteger(days) || days < 1 || days > 365) throw new Error('Validation: Số ngày dự báo phải từ 1 đến 365');
        const asOf = vietnamDateKey(now);
        return AppDataSource.transaction('REPEATABLE READ', async manager => {
            await manager.query('SET TRANSACTION READ ONLY');
            const cash = await manager.query("SELECT COALESCE(SUM(CASE WHEN type='INCOME' THEN amount WHEN type='EXPENSE' THEN -amount ELSE 0 END),0) AS balance FROM cash_transactions WHERE shop_id=$1 AND transaction_date <= $2::date", [shopId, asOf]);
            const effects = await readOpeningBalanceEffects(manager,{shopId,asOf});
            const dueBalances = async (kind: 'RECEIVABLE' | 'PAYABLE') => {
                const table = kind === 'RECEIVABLE' ? 'receivables' : 'payables';
                return manager.query(`SELECT TO_CHAR(d.due_date,'YYYY-MM-DD') AS date,
                    SUM(GREATEST(d.amount-COALESCE(d.paid_amount,0)+COALESCE(e.adjustment_amount,0),0)) AS amount
                    FROM ${table} d LEFT JOIN jsonb_to_recordset($3::jsonb)
                      AS e(id integer,adjustment_amount numeric,opening_date date) ON e.id=d.id
                    WHERE d.shop_id=$1 AND d.status<>'CANCELLED'
                      AND (e.opening_date IS NULL OR e.opening_date <= $2::date)
                    GROUP BY d.due_date
                    HAVING SUM(GREATEST(d.amount-COALESCE(d.paid_amount,0)+COALESCE(e.adjustment_amount,0),0))>0`,
                    [shopId,asOf,JSON.stringify(openingDebtEffectRows(effects,kind))]);
            };
            const receivables = await dueBalances('RECEIVABLE');
            const payables = await dueBalances('PAYABLE');
            const plans = await manager.query("SELECT TO_CHAR(forecast_date,'YYYY-MM-DD') AS date, SUM(expected_income) AS income, SUM(expected_expense) AS expense FROM cashflow_forecasts WHERE shop_id=$1 AND forecast_date > $2::date GROUP BY forecast_date", [shopId, asOf]);
            const bookBalance = openingEffectValue(openingEffectCents(cash[0].balance) + effects.cashCents + effects.bankCents);
            return buildCashflowProjection({ asOf, days, bookBalance, receivables, payables, plans });
        });
    }

    async getForecasts(shopId: number) {
        const items = await this.forecastRepo.find({ where: { shopId }, order: { forecastDate: 'ASC' } });
        return Array.isArray(items) ? items : (items ? [items] : []);
    }
    async createForecast(shopId: number, dto: Partial<CashflowForecast>) {
        const normalized = normalizeCashflowForecastInput(dto);
        return this.forecastRepo.save(this.forecastRepo.create({ ...normalized, shopId }));
    }
    async updateForecast(shopId: number, id: number, dto: Partial<CashflowForecast>) {
        const record = await this.forecastRepo.findOne({ where: { id, shopId } });
        if (!record) throw new Error('Not found');
        Object.assign(record, normalizeCashflowForecastInput(dto, record));
        return this.forecastRepo.save(record);
    }
    async deleteForecast(shopId: number, id: number) {
        const record = await this.forecastRepo.findOne({ where: { id, shopId } });
        if (record) await this.forecastRepo.remove(record);
    }

    // Budget Plans
    async getBudgetPlans(shopId: number) {
        const plans = await this.budgetRepo.find({
            where: { shopId },
            order: { startDate: 'DESC' },
        });
        return Promise.all(plans.map(async plan => {
            const startDateKey = vietnamDateKey(new Date(plan.startDate));
            const endDateKey = vietnamDateKey(new Date(plan.endDate));
            const actual = await this.cashTxRepo.createQueryBuilder('t')
                .select("COALESCE(SUM(CASE WHEN t.type = 'INCOME' THEN t.amount ELSE 0 END), 0)", 'actualIncome')
                .addSelect("COALESCE(SUM(CASE WHEN t.type = 'EXPENSE' THEN t.amount ELSE 0 END), 0)", 'actualExpense')
                .where('t.shop_id = :shopId', { shopId })
                .andWhere('t.transaction_date BETWEEN CAST(:startDate AS date) AND CAST(:endDate AS date)', {
                    startDate: startDateKey,
                    endDate: endDateKey,
                })
                .getRawOne();
            return {
                ...plan,
                actualIncome: Number(actual?.actualIncome || 0),
                actualExpense: Number(actual?.actualExpense || 0),
            };
        }));
    }
    async createBudgetPlan(shopId: number, dto: Partial<BudgetPlan>) {
        const normalized = normalizeBudgetPlanInput(dto);
        return this.budgetRepo.save(this.budgetRepo.create({ ...normalized, shopId }));
    }
    async updateBudgetPlan(shopId: number, id: number, dto: Partial<BudgetPlan>) {
        const record = await this.budgetRepo.findOne({ where: { id, shopId } });
        if (!record) throw new Error('Not found');
        Object.assign(record, normalizeBudgetPlanInput(dto, record));
        return this.budgetRepo.save(record);
    }
    async deleteBudgetPlan(shopId: number, id: number) {
        const record = await this.budgetRepo.findOne({ where: { id, shopId } });
        if (record) await this.budgetRepo.remove(record);
    }

    // Invoices
    async getInvoices(
        shopId: number,
        page = 1,
        limit = 20,
        type?: string,
        from?: string,
        to?: string,
    ) {
        const query = normalizeInvoiceListQuery({ page, limit, type, from, to });
        const qb = this.invoiceRepo.createQueryBuilder('i')
            .where('i.shop_id = :shopId', { shopId });
        if (query.type) {
            qb.andWhere('i.invoice_type = :type', { type: query.type });
        }
        if (query.fromDate && query.toDate) {
            qb.andWhere(
                'i.invoice_date >= :fromDate AND i.invoice_date <= :toDate',
                { fromDate: query.fromDate, toDate: query.toDate },
            );
        }
        const [items, total] = await qb.orderBy('i.invoice_date', 'DESC')
            .skip((query.page - 1) * query.limit)
            .take(query.limit)
            .getManyAndCount();
        return {
            items,
            total,
            page: query.page,
            limit: query.limit,
            totalPages: Math.ceil(total / query.limit),
            filters: {
                type: query.type || null,
                from: from || null,
                to: to || null,
            },
        };
    }
    async getInvoiceSummary(shopId: number, from?: string, to?: string) {
        const { fromDate, toDate } = resolveCurrentMonthExpensePeriod(from, to);

        const result = await this.invoiceRepo.createQueryBuilder('i')
            .select("COALESCE(SUM(CASE WHEN i.invoice_type = 'IN' THEN i.tax_amount ELSE 0 END), 0)", 'vatIn')
            .addSelect("COALESCE(SUM(CASE WHEN i.invoice_type = 'OUT' THEN i.tax_amount ELSE 0 END), 0)", 'vatOut')
            .where('i.shop_id = :shopId AND i.invoice_date >= :fromDate AND i.invoice_date <= :toDate', { shopId, fromDate, toDate })
            .getRawOne();

        const vatIn = normalizeNonNegative(Number(result?.vatIn || 0));
        const vatOut = normalizeNonNegative(Number(result?.vatOut || 0));
        const vatBalance = calculateOutstandingTax(vatOut, vatIn);
        return {
            vatIn,
            vatOut,
            vatOwed: vatBalance.owed,
            vatCredit: vatBalance.overpaid,
        };
    }
    async getInvoiceById(shopId: number, id: number) {
        const invoice = await this.invoiceRepo.findOne({
            where: { id, shopId },
            relations: ['items', 'items.product'],
        });
        if (!invoice) throw new Error('Invoice not found');
        return invoice;
    }
    async createInvoice(shopId: number, dto: Partial<Invoice> & { type?: string }) {
        return AppDataSource.transaction(async manager => {
            await lockShopMutation(manager, shopId);
            if ((dto as any).referenceType != null || (dto as any).referenceId != null) {
                throw new Error('Validation: Invoice source reference is server-controlled');
            }
            const hasItems = Object.prototype.hasOwnProperty.call(dto, 'items');
            const itemSummary = hasItems
                ? normalizeInvoiceItems((dto as any).items)
                : null;
            if (itemSummary) {
                await this.validateInvoiceItemProducts(
                    manager,
                    shopId,
                    itemSummary.items.map(item => item.productId),
                );
            }
            const normalized = normalizeInvoiceInput(
                itemSummary
                    ? { ...dto, subtotal: itemSummary.subtotal, taxAmount: itemSummary.taxAmount }
                    : dto,
            );
            const safeDto: any = { ...dto, ...normalized };
            safeDto.invoiceNumber = String(dto.invoiceNumber || '').trim()
                || 'HD' + Date.now().toString().slice(-8);
            delete safeDto.id;
            delete safeDto.shopId;
            delete safeDto.createdAt;
            delete safeDto.type;
            delete safeDto.items;
            const invoiceRepo = manager.getRepository(Invoice);
            const invoice = invoiceRepo.create({
                ...safeDto,
                shopId,
            } as Partial<Invoice>) as Invoice;
            await invoiceRepo.save(invoice);
            if (itemSummary) {
                invoice.items = itemSummary.items.map(item => manager.getRepository(InvoiceItem).create({
                    invoice,
                    productId: item.productId,
                    itemName: item.itemName,
                    unit: item.unit,
                    quantity: item.quantity,
                    unitPrice: item.unitPrice,
                    subtotal: item.subtotal,
                    taxRate: item.taxRate,
                    taxAmount: item.taxAmount,
                }));
            }
            if (invoice.items?.length) await manager.getRepository(InvoiceItem).save(invoice.items);
            return invoice;
        });
    }

    private async validateInvoiceItemProducts(
        manager: EntityManager,
        shopId: number,
        productIds: Array<number | null>,
    ) {
        const ids = [...new Set(productIds.filter((id): id is number => id != null))];
        if (ids.length === 0) return;
        const count = await manager.getRepository(Product).count({
            where: { id: In(ids), shopId },
        });
        if (count !== ids.length) {
            throw new Error('Validation: Có sản phẩm không thuộc cửa hàng hiện tại');
        }
    }


    // Tax Obligations
    async getTaxObligations(shopId: number) {
        const items = await this.taxObRepo.find({ where: { shopId }, order: { period: 'DESC' } });
        const safeItems = items.map((item) => ({
            ...item,
            vatDeclared: normalizeNonNegative(Number(item.vatDeclared)),
            pitDeclared: normalizeNonNegative(Number(item.pitDeclared)),
            vatPaid: normalizeNonNegative(Number(item.vatPaid)),
            pitPaid: normalizeNonNegative(Number(item.pitPaid)),
        }));
        const totalVat = safeItems.reduce((s, i) => s + i.vatDeclared, 0);
        const totalPit = safeItems.reduce((s, i) => s + i.pitDeclared, 0);
        const totalPaidVat = safeItems.reduce((s, i) => s + i.vatPaid, 0);
        const totalPaidPit = safeItems.reduce((s, i) => s + i.pitPaid, 0);
        const balance = calculateOutstandingTax(
            totalVat + totalPit,
            totalPaidVat + totalPaidPit,
        );
        return {
            items: safeItems,
            totalVat,
            totalPit,
            totalPaidVat,
            totalPaidPit,
            totalOwed: balance.owed,
            totalOverpaid: balance.overpaid,
        };
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
    async getPurchasesWithoutInvoice(shopId: number, page = 1, limit = 20, status?: string) {
        const safePage = Math.max(1, Math.trunc(Number(page) || 1));
        const safeLimit = Math.min(100, Math.max(1, Math.trunc(Number(limit) || 20)));
        const normalizedStatus = status?.trim().toUpperCase() || undefined;
        if (normalizedStatus && !['PENDING', 'APPROVED', 'REJECTED'].includes(normalizedStatus)) {
            throw new Error('Validation: Trạng thái phê duyệt không hợp lệ');
        }
        const qb = this.purchaseNoInvRepo.createQueryBuilder('purchase')
            .leftJoinAndSelect('purchase.items', 'items')
            .where('purchase.shopId = :shopId', { shopId });
        if (normalizedStatus) {
            qb.andWhere('purchase.approvalStatus = :status', { status: normalizedStatus });
        }
        const totalQb = this.purchaseNoInvRepo.createQueryBuilder('purchase_total')
            .select('COALESCE(SUM(purchase_total.totalAmount), 0)', 'filteredAmountTotal')
            .where('purchase_total.shopId = :shopId', { shopId });
        if (normalizedStatus) {
            totalQb.andWhere('purchase_total.approvalStatus = :status', { status: normalizedStatus });
        }
        const totalRow = await totalQb.getRawOne();
        const [items, total] = await qb
            .orderBy('purchase.purchaseDate', 'DESC')
            .skip((safePage - 1) * safeLimit)
            .take(safeLimit)
            .getManyAndCount();
        return {
            items,
            total,
            filteredAmountTotal: Number(totalRow?.filteredAmountTotal || 0),
            page: safePage,
            limit: safeLimit,
            totalPages: Math.ceil(total / safeLimit),
        };
    }

    async createPurchaseWithoutInvoice(shopId: number, dto: Partial<PurchaseWithoutInvoice> & {
        items?: Array<Partial<PurchaseWithoutInvoiceItem>>;
        creatorUserId?: number;
        creatorRole?: string;
        creatorAccountType?: string;
        requestIp?: string;
    }) {
        dto = { ...dto, purchaseDate: assertPastOrToday(dto.purchaseDate || new Date(), 'Ngày mua hàng') };
        if (!dto.recordCode) dto.recordCode = 'BK-' + Date.now().toString().slice(-6);

        const sellerName = String(dto.sellerName || '').trim();
        const sellerIdentityNumber = String(dto.sellerIdentityNumber || '').trim();
        if (!sellerName) throw new Error('Validation: Tên người bán là bắt buộc');
        if (!sellerIdentityNumber) throw new Error('Validation: CCCD người bán là bắt buộc');

        const rawItems = Array.isArray(dto.items) ? dto.items : [];
        const items = rawItems
            .map((i: any) => {
                const productName = String(i.productName || i.itemName || i.name || '').trim();
                const productId = i.productId ? Number(i.productId) : undefined;
                const warehouseId = i.warehouseId ? Number(i.warehouseId) : undefined;
                const quantity = Number(i.quantity || 0);
                const unitPrice = Number(i.unitPrice || 0);
                const subtotal = Number(i.subtotal || (quantity * unitPrice));
                if (
                    !productName ||
                    !Number.isFinite(quantity) ||
                    !Number.isFinite(unitPrice) ||
                    !Number.isFinite(subtotal) ||
                    quantity <= 0 ||
                    unitPrice < 0 ||
                    subtotal < 0 ||
                    (productId !== undefined && (!Number.isInteger(productId) || productId <= 0)) ||
                    (warehouseId !== undefined && (!Number.isInteger(warehouseId) || warehouseId <= 0))
                ) return null;
                return {
                    productName,
                    productId,
                    warehouseId,
                    quantity,
                    unitPrice,
                    subtotal,
                    shopId,
                } as PurchaseWithoutInvoiceItem;
            })
            .filter((i): i is PurchaseWithoutInvoiceItem => !!i);

        if (items.length === 0 || items.length !== rawItems.length) {
            throw new Error('Validation: Bảng kê phải có ít nhất 1 mặt hàng hợp lệ (cần productName/itemName, quantity > 0, unitPrice >= 0)');
        }

        let defaultWarehouse: Warehouse | null = null;
        for (const item of items) {
            if (!item.productId) continue;
            if (!item.warehouseId) {
                defaultWarehouse ??= await AppDataSource.getRepository(Warehouse).findOne({
                    where: { shopId, isActive: true },
                    order: { id: 'ASC' },
                });
                if (!defaultWarehouse) {
                    throw new Error('Validation: Cửa hàng chưa có kho hoạt động để nhận hàng');
                }
                item.warehouseId = defaultWarehouse.id;
            }
            const [product, warehouse] = await Promise.all([
                AppDataSource.getRepository(Product).findOne({
                    where: { id: item.productId, shopId, isActive: true },
                }),
                AppDataSource.getRepository(Warehouse).findOne({
                    where: { id: item.warehouseId, shopId },
                }),
            ]);
            if (!product) throw new Error('Validation: Sản phẩm không thuộc cửa hàng');
            if (!warehouse) throw new Error('Validation: Kho nhận hàng không thuộc cửa hàng');
        }

        const computedTotal = items.reduce((sum, i) => sum + Number(i.subtotal), 0);
        const totalAmount = computedTotal > 0 ? computedTotal : Number(dto.totalAmount || 0);
        if (totalAmount <= 0) {
            throw new Error('Validation: Tổng tiền bảng kê phải lớn hơn 0');
        }

        const systemService = new SystemService();
        const cashPurchaseLimitConfig = await systemService.getSystemConfig(shopId, 'CASH_PURCHASE_LIMIT');
        const cashPurchaseLimit = Number(cashPurchaseLimitConfig);

        if (totalAmount >= cashPurchaseLimit && dto.paymentMethod === 'CASH') {
            throw new Error(`Validation: Giao dịch mua hàng không hóa đơn có giá trị từ ${cashPurchaseLimit.toLocaleString('vi-VN')} đồng trở lên bắt buộc phải chuyển khoản để được tính là chi phí hợp lý (theo luật thuế TNDN).`);
        }

        const isOwner = dto.creatorAccountType === 'SHOP';
        const approvalStatus = isOwner ? 'APPROVED' : 'PENDING';
        const approvedBy = isOwner ? dto.creatorUserId : null;
        const approvedAt = isOwner ? new Date() : null;

        const saved = await AppDataSource.transaction(async (manager) => {
            await lockShopMutation(manager, shopId);
            const repo = manager.getRepository(PurchaseWithoutInvoice);
            const entity = repo.create({
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
            const created = await repo.save(entity);
            if (isOwner) {
                await this.applyApprovedPurchaseWithoutInvoice(
                    shopId,
                    created,
                    manager,
                    dto.creatorUserId,
                );
            }
            return created;
        });

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
        if (input.approverAccountType !== 'SHOP') {
            throw new Error('Validation: Chỉ chủ shop mới có quyền duyệt bảng kê');
        }
        const result = await AppDataSource.transaction(async (manager) => {
            await lockShopMutation(manager, shopId);
            const repo = manager.getRepository(PurchaseWithoutInvoice);
            const record = await repo.findOne({
                where: { id, shopId },
                relations: ['items'],
            });
            if (!record) throw new Error('Validation: Không tìm thấy bảng kê');

            const currentStatus = String(record.approvalStatus || 'PENDING').toUpperCase();
            if (currentStatus !== 'PENDING') {
                if (currentStatus === input.decision) {
                    return { updated: record, changed: false, oldValue: '' };
                }
                throw new Error('Validation: Bảng kê đã được xử lý và không thể đổi quyết định');
            }

            const oldValue = JSON.stringify({
                approvalStatus: record.approvalStatus,
                approvalNotes: record.approvalNotes,
            });
            record.approvalStatus = input.decision;
            record.approvalNotes = input.approvalNotes?.trim() || null as any;
            record.approvedBy = input.approverUserId as any;
            record.approvedAt = new Date();
            const updated = await repo.save(record);

            if (input.decision === 'APPROVED') {
                await this.applyApprovedPurchaseWithoutInvoice(
                    shopId,
                    updated,
                    manager,
                    input.approverUserId,
                );
            }
            return { updated, changed: true, oldValue };
        });

        const { updated, changed, oldValue } = result;
        if (!changed) return updated;

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

    private async applyApprovedPurchaseWithoutInvoice(
        shopId: number,
        record: PurchaseWithoutInvoice,
        manager: EntityManager,
        createdBy?: number,
    ) {
        const movementRepo = manager.getRepository(InventoryMovement);
        const stockRepo = manager.getRepository(InventoryStock);
        const cogsService = new COGSService();

        for (const item of record.items || []) {
            if (!item.productId || !item.warehouseId) continue;
            await movementRepo.save(movementRepo.create({
                shopId,
                productId: Number(item.productId),
                warehouseId: Number(item.warehouseId),
                movementType: 'IN',
                quantity: Number(item.quantity),
                referenceType: 'PURCHASE_NO_INVOICE',
                referenceId: record.id,
                notes: `Bảng kê 01: ${record.recordCode}`,
            }));

            let stock = await stockRepo.findOne({
                where: {
                    shopId,
                    productId: Number(item.productId),
                    warehouseId: Number(item.warehouseId),
                } as any,
            });
            if (!stock) {
                stock = stockRepo.create({
                    shopId,
                    productId: Number(item.productId),
                    warehouseId: Number(item.warehouseId),
                    quantity: 0,
                    updatedAt: new Date(),
                });
            }
            stock.quantity = Number(stock.quantity || 0) + Number(item.quantity);
            stock.updatedAt = new Date();
            await stockRepo.save(stock);

            await cogsService.addInventoryLot({
                productId: Number(item.productId),
                quantity: Number(item.quantity),
                costPrice: Number(item.unitPrice),
                purchaseId: record.id,
                notes: `Bảng kê 01: ${record.recordCode}`,
                shopId,
                lotDate: new Date(record.purchaseDate),
            }, manager);
        }

        const paymentMethod = record.paymentMethod || 'CASH';
        await this.createCashTransaction(shopId, {
            amount: Number(record.totalAmount),
            type: 'EXPENSE',
            category: 'PURCHASE',
            paymentMethod,
            referenceType: 'PURCHASE_WITHOUT_INVOICE',
            referenceId: record.id,
            referenceCode: record.recordCode,
            transactionDate: record.purchaseDate || new Date(),
            status: 'COMPLETED',
            createdBy,
            notes: `Chi mua hàng không hóa đơn: ${record.recordCode}`,
        } as any, manager);

        await this.postingService.postJournal(
            shopId,
            'PURCHASE_WITHOUT_INVOICE',
            record.id,
            `Chi mua hàng không hóa đơn: ${record.recordCode}`,
            [
                {
                    accountCode: '156',
                    amount: Number(record.totalAmount),
                    entryType: 'DEBIT',
                },
                {
                    accountCode: cashLedgerAccountCode(paymentMethod),
                    amount: Number(record.totalAmount),
                    entryType: 'CREDIT',
                },
            ],
            manager,
            new Date(record.purchaseDate),
        );
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
        for (const field of ['vatDeclared', 'pitDeclared', 'vatPaid', 'pitPaid']) {
            if (normalized[field] !== undefined) {
                normalized[field] = normalizeNonNegative(Number(normalized[field]));
            }
        }
        delete normalized.vatAmount;
        delete normalized.pitAmount;
        delete normalized.paidVatAmount;
        delete normalized.paidPitAmount;
        return normalized;
    }
}
