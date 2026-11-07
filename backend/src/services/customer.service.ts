import { lockShopMutation } from '../utils/shop-mutation-lock';
import { AppDataSource } from '../config/db.config';
import {
    Customer,
    DebtEvidence,
    DebtPaymentHistory,
    Receivable,
} from '../customer/entities';
import { config } from '../config/env.config';
import {
    debtEvidenceImageKeyFromPublicUrl,
    ImageStorageService,
    MAX_PRODUCT_IMAGE_BYTES,
} from './image-storage.service';
import { EntityManager, In } from 'typeorm';
import { SalesOrder } from '../sales/entities';
import { calculateRemainingDebt } from '../customer/debt.utils';
import { readOpeningBalanceEffects, openingAdjustedDebt, openingEffectCents, openingEffectValue, openingDebtEffectRows, OpeningBalanceEffects } from '../finance/opening-balance-effects.repository';
import { classifyDebtAging } from '../customer/debt-aging.utils';
import { resolveVietnamBusinessDayEnd } from '../finance/finance-period.utils';
import { normalizeCustomerInput } from '../party/party-input.utils';
import { FinanceService } from './finance.service';
import { PostingService } from './posting.service';
import {
    normalizeSettledPaymentMethod,
    paymentLedgerAccountCode,
} from '../sales/payment-ledger.utils';
import {
    normalizeReceivableListQuery,
    ReceivableListQueryInput,
    NormalizedReceivableListQuery,
} from '../customer/receivable-list-query.utils';
import { vietnamDateKey } from '../finance/finance-period.utils';
import {
    vietnameseSearchExpression,
    vietnameseSearchParams,
} from '../common/vietnamese-search.utils';

const OPEN_RECEIVABLE_REMAINING = '(receivable.amount - COALESCE(receivable.paidAmount, 0) + COALESCE(opening_effect.adjustment_amount, 0))';

export class CustomerService {
    private customerRepo = AppDataSource.getRepository(Customer);
    private receivableRepo = AppDataSource.getRepository(Receivable);
    private evidenceRepo = AppDataSource.getRepository(DebtEvidence);
    private imageStorageService = new ImageStorageService();
    private orderRepo = AppDataSource.getRepository(SalesOrder);
    private financeService = new FinanceService();
    private postingService = new PostingService();

    async findAll(shopId: number, page = 1, limit = 20, search?: string) {
        return this.withReceivableSnapshot(shopId, async (manager, effects, balanceAsOf) => {
            const qb = manager.getRepository(Customer).createQueryBuilder('c')
                .where('c.shopId = :shopId AND c.isActive = :isActive', { shopId, isActive: true });
            if (search?.trim()) {
                qb.andWhere(
                    `(${vietnameseSearchExpression('c.name')} OR ${vietnameseSearchExpression('c.phone')} OR ${vietnameseSearchExpression('c.code')})`,
                    vietnameseSearchParams(search),
                );
            }
            const [items, total] = await qb.skip((page - 1) * limit).take(limit).orderBy('c.createdAt', 'DESC').addOrderBy('c.id', 'DESC').getManyAndCount();
            return { items: await this.withCustomerBalances(manager, items, effects, balanceAsOf, shopId), total, page, limit, totalPages: Math.ceil(total / limit) };
        });
    }

    async findById(shopId: number, id: number) {
        return this.withReceivableSnapshot(shopId, async (manager, effects, balanceAsOf) => {
            const customer = await manager.findOne(Customer, { where: { id, shopId } });
            if (!customer) throw new Error('Customer not found');
            return (await this.withCustomerBalances(manager, [customer], effects, balanceAsOf, shopId))[0];
        });
    }

    private async withCustomerBalances(manager: EntityManager, customers: Customer[], effects: OpeningBalanceEffects, balanceAsOf: string, shopId: number) {
        if (!customers.length) return [];
        const rows = await this.buildOpenReceivableQuery(shopId, normalizeReceivableListQuery({ asOf: balanceAsOf }), manager, effects, balanceAsOf)
            .andWhere('receivable.customer_id IN (:...customerIds)', { customerIds: customers.map(customer => customer.id) })
            .orderBy()
            .select('receivable.customer_id', 'customerId')
            .addSelect(`SUM(${OPEN_RECEIVABLE_REMAINING})`, 'balance')
            .groupBy('receivable.customer_id')
            .getRawMany();
        const balances = new Map(rows.map(row => [Number(row.customerId), openingEffectValue(openingEffectCents(row.balance))]));
        return customers.map(customer => ({ ...customer, balance: balances.get(customer.id) ?? 0, balanceAsOf, balanceBasis: 'CURRENT' as const }));
    }

    async balanceInTransaction(manager: EntityManager, customer: Customer, balanceAsOf: string) {
        if (!manager.queryRunner?.isTransactionActive) throw new Error('Customer balance requires an active transaction');
        const effects = await readOpeningBalanceEffects(manager,{shopId:customer.shopId,asOf:balanceAsOf,includeCash:false,payableIds:[]});
        return (await this.withCustomerBalances(manager,[customer],effects,balanceAsOf,customer.shopId))[0].balance;
    }

    async create(shopId: number, dto: Partial<Customer>) {
        return this.customerRepo.save(this.customerRepo.create({ ...normalizeCustomerInput(dto, true), shopId, code: 'CUS' + Date.now().toString().slice(-6) }));
    }

    async update(shopId: number, id: number, dto: Partial<Customer>) {
        return this.changeCustomerProfile(shopId, id, normalizeCustomerInput(dto));
    }

    async remove(shopId: number, id: number) {
        return this.changeCustomerProfile(shopId, id, { isActive: false });
    }

    private async changeCustomerProfile(shopId: number, id: number, patch: Record<string, unknown>) {
        return AppDataSource.transaction(async manager => {
            await lockShopMutation(manager, shopId);
            if (!await manager.findOne(Customer, { where: { id, shopId } })) throw new Error('Customer not found');
            // Never save a read model or a stale financial balance with profile fields.
            if (Object.keys(patch).length) await manager.update(Customer, { id, shopId }, patch);
            const customer = await manager.findOne(Customer, { where: { id, shopId } });
            if (!customer) throw new Error('Customer not found');
            const balanceAsOf = vietnamDateKey(new Date());
            const effects = await readOpeningBalanceEffects(manager, { shopId, asOf: balanceAsOf, includeCash: false, payableIds: [] });
            return (await this.withCustomerBalances(manager, [customer], effects, balanceAsOf, shopId))[0];
        });
    }

    async getReceivables(shopId: number, customerId: number) {
        return this.withReceivableSnapshot(shopId, async (manager, effects, balanceAsOf) => {
            const records = await manager.getRepository(Receivable).createQueryBuilder('receivable')
                .innerJoin('receivable.customer', 'customer', 'customer.shopId = :shopId', { shopId })
                .leftJoinAndSelect('receivable.evidences', 'evidence', '(evidence.shopId = :shopId OR evidence.shopId IS NULL)', { shopId })
                .leftJoinAndSelect('receivable.paymentHistory', 'paymentHistory', '(paymentHistory.shopId = :shopId OR paymentHistory.shopId IS NULL)', { shopId })
                .where('receivable.shopId = :shopId AND customer.id = :customerId', { shopId, customerId })
                .orderBy('receivable.createdAt', 'ASC').addOrderBy('receivable.id', 'ASC')
                .getMany();
            return records.map(record => {
                const adjustment = effects.receivableCents.get(record.id) ?? 0n;
                const openingEffective = (effects.receivableDates.get(record.id) ?? '') <= balanceAsOf;
                const debt = openingEffective && record.status !== 'CANCELLED'
                    ? openingAdjustedDebt(record.amount, record.paidAmount, adjustment) : null;
                const remaining = openingEffectValue(debt?.remainingCents ?? 0n);
                return {
                    ...record, remaining, remainingAmount: remaining, openingAdjustmentAmount: openingEffectValue(adjustment),
                    openingEffective, closedByAdjustment: debt?.closedByAdjustment ?? false, balanceAsOf, balanceBasis: 'CURRENT' as const
                };
            });
        });
    }

    async createReceivable(shopId: number, customerId: number, dto: Partial<Receivable>) {
        const amount = Number(dto.amount);
        const paidAmount = Number(dto.paidAmount || 0);
        const dueDate = dto.dueDate ? new Date(dto.dueDate) : null;
        if (!Number.isFinite(amount) || amount <= 0) {
            throw new Error('Validation: Amount must be greater than zero');
        }
        if (!Number.isFinite(paidAmount) || paidAmount < 0 || paidAmount > amount) {
            throw new Error('Validation: Paid amount is invalid');
        }
        if (!dueDate || Number.isNaN(dueDate.getTime())) {
            throw new Error('Validation: Due date is required');
        }

        return AppDataSource.transaction(async (manager) => {
            await lockShopMutation(manager, shopId);
            const customer = await manager.findOne(Customer, {
                where: { id: customerId, shopId, isActive: true },
            });
            if (!customer) throw new Error('Customer not found');

            const remaining = calculateRemainingDebt(amount, paidAmount);
            const receivable = manager.create(Receivable, {
                shopId,
                customer,
                amount,
                paidAmount,
                dueDate,
                status: remaining <= 0 ? 'PAID' : dueDate < new Date() ? 'OVERDUE' : paidAmount > 0 ? 'PARTIAL' : 'UNPAID',
                notes: dto.notes,
                debtReason: dto.debtReason,
                witnessName: dto.witnessName,
                reminderEnabled: dto.reminderEnabled === true,
            });
            const saved = await manager.save(Receivable, receivable);
            customer.balance = Number(customer.balance || 0) + remaining;
            await manager.save(Customer, customer);
            return saved;
        });
    }

    async collectManualReceivablePayment(
        shopId: number,
        receivableId: number,
        recordedBy: number | undefined,
        dto: { amount?: unknown; method?: unknown; notes?: unknown },
        now = new Date(),
    ) {
        const amount = Number(dto.amount);
        if (!Number.isFinite(amount) || amount <= 0) {
            throw new Error('Validation: Payment amount must be greater than 0');
        }
        let paymentCents: bigint;
        try {
            paymentCents = openingEffectCents(String(dto.amount).trim());
        } catch {
            throw new Error('Validation: Số tiền thanh toán phải có tối đa hai chữ số thập phân');
        }
        const paymentMethod = normalizeSettledPaymentMethod(
            String(dto.method || 'CASH'),
        );
        const notes = String(dto.notes || '').trim();
        if (notes.length > 500) {
            throw new Error('Validation: Notes must not exceed 500 characters');
        }

        return AppDataSource.transaction(async (manager) => {
            await lockShopMutation(manager, shopId);
            const receivable = await manager.findOne(Receivable, {
                where: { id: receivableId, shopId },
                relations: ['customer'],
                // Shop mutation lock already serializes collections; do not FOR UPDATE a nullable joined customer.

            });
            if (!receivable) throw new Error('Receivable not found');
            if (receivable.status === 'CANCELLED') {
                throw new Error('Validation: Receivable is already closed');
            }
            if (Number(receivable.orderId) > 0) {
                throw new Error(
                    'Validation: Linked receivable must use the sales order payment workflow',
                );
            }

            const effects = await readOpeningBalanceEffects(manager, {
                shopId,asOf:vietnamDateKey(now),includeCash:false,receivableIds:[receivable.id],payableIds:[],
            });
            if ((effects.receivableDates.get(receivable.id) ?? '') > vietnamDateKey(now)) {
                throw new Error('Validation: Khoản nợ chưa có hiệu lực tại ngày thanh toán');
            }
            const adjustment = effects.receivableCents.get(receivable.id) ?? 0n;
            const before = openingAdjustedDebt(receivable.amount,receivable.paidAmount,adjustment);
            if (before.remainingCents === 0n) throw new Error('Validation: Receivable is already closed');
            if (paymentCents > before.remainingCents) {
                throw new Error(
                    'Validation: Payment amount exceeds remaining receivable balance',
                );
            }

            receivable.paidAmount = openingEffectValue(before.paidCents + paymentCents);
            const after = openingAdjustedDebt(receivable.amount,receivable.paidAmount,adjustment);
            const remaining = openingEffectValue(after.remainingCents);
            receivable.status = remaining === 0 ? 'PAID' : 'PARTIAL';
            await manager.save(Receivable, receivable);

            const history = await manager.save(
                DebtPaymentHistory,
                manager.create(DebtPaymentHistory, {
                    shopId,
                    receivable,
                    amount,
                    paymentMethod,
                    paymentDate: now,
                    notes: notes || undefined,
                    recordedBy,
                }),
            );

            const customer = receivable.customer?.shopId === shopId
                ? receivable.customer
                : undefined;
            if (!customer) throw new Error('Customer not found');
            const customerBalance = openingEffectCents(customer.balance || 0) - paymentCents;
            customer.balance = openingEffectValue(customerBalance > 0n ? customerBalance : 0n);
            await manager.save(Customer, customer);

            await this.financeService.createCashTransaction(shopId, {
                amount,
                type: 'INCOME',
                category: 'DEBT_COLLECTION',
                paymentMethod,
                referenceType: 'DEBT_COLLECTION',
                referenceId: receivable.id,
                counterparty: customer.name,
                description: `Thu nợ khách hàng ${customer.name}`,
                transactionDate: now,
                createdBy: recordedBy,
            } as any, manager);
            await this.postingService.postJournal(
                shopId,
                'DEBT_COLLECTION',
                receivable.id,
                `Thu nợ khách hàng ${customer.name}`,
                [
                    {
                        accountCode: paymentLedgerAccountCode(paymentMethod),
                        amount,
                        entryType: 'DEBIT',
                    },
                    { accountCode: '131', amount, entryType: 'CREDIT' },
                ],
                manager,
                now,
            );

            return {
                receivableId: receivable.id,
                paymentHistoryId: history.id,
                paidAmount: Number(receivable.paidAmount),
                remaining,
                openingAdjustmentAmount: openingEffectValue(adjustment),
                status: receivable.status,
            };
        });
    }

    private async withReceivableSnapshot<T>(shopId: number, work: (
        manager: EntityManager, effects: OpeningBalanceEffects, balanceAsOf: string,
    ) => Promise<T>): Promise<T> {
        const balanceAsOf = vietnamDateKey(new Date());
        return AppDataSource.transaction('REPEATABLE READ', async manager => {
            await manager.query('SET TRANSACTION READ ONLY');
            const effects = await readOpeningBalanceEffects(manager, { shopId, asOf: balanceAsOf, includeCash: false, payableIds: [] });
            return work(manager, effects, balanceAsOf);
        });
    }

    async getOpenReceivables(shopId: number) {
        const query = normalizeReceivableListQuery({});
        return this.withReceivableSnapshot(shopId, async (manager, effects, balanceAsOf) => {
            const records = await this.buildOpenReceivableQuery(shopId, query, manager, effects, balanceAsOf).getMany();
            return this.mapOpenReceivableRows(shopId, records, query.asOf, manager, effects);
        });
    }

    private buildOpenReceivableQuery(
        shopId: number,
        query: NormalizedReceivableListQuery,
        manager: EntityManager,
        effects: OpeningBalanceEffects,
        balanceAsOf: string,
    ) {
        const asOfDate = vietnamDateKey(query.asOf);
        const qb = manager.getRepository(Receivable).createQueryBuilder('receivable')
            .leftJoinAndSelect(
                'receivable.customer',
                'customer',
                'customer.shopId = :shopId',
                { shopId },
            )
            .leftJoin(
                SalesOrder,
                'salesOrder',
                'salesOrder.id = receivable.orderId AND salesOrder.shopId = :shopId',
                { shopId },
            )
            .leftJoin(
                '(SELECT * FROM jsonb_to_recordset(CAST(:openingDebtRows AS jsonb)) AS e(id integer,adjustment_amount numeric,opening_date date))',
                'opening_effect', 'opening_effect.id = receivable.id',
                { openingDebtRows: JSON.stringify(openingDebtEffectRows(effects, 'RECEIVABLE')) },
            )
            .where('receivable.shopId = :shopId', { shopId })
            .andWhere('receivable.status <> :cancelled', { cancelled: 'CANCELLED' })
            .andWhere(`${OPEN_RECEIVABLE_REMAINING} > 0`)
            .andWhere('(opening_effect.opening_date IS NULL OR opening_effect.opening_date <= :balanceAsOf)', { balanceAsOf });

        if (query.search?.trim()) {
            qb.andWhere(
                `(${vietnameseSearchExpression('customer.name')} OR ${vietnameseSearchExpression('customer.phone')} OR ${vietnameseSearchExpression('customer.zaloPhone')} OR ${vietnameseSearchExpression('customer.code')} OR ${vietnameseSearchExpression('salesOrder.orderCode')})`,
                vietnameseSearchParams(query.search),
            );
        }
        if (query.status === 'OVERDUE') {
            qb.andWhere('receivable.dueDate < :asOfDate', { asOfDate });
        } else if (query.status === 'CURRENT') {
            qb.andWhere('receivable.dueDate >= :asOfDate', { asOfDate });
        }

        if (query.sort === 'REMAINING_DESC') {
            qb.addSelect(OPEN_RECEIVABLE_REMAINING, 'effective_remaining_sort')
                .orderBy('effective_remaining_sort', 'DESC').addOrderBy('receivable.dueDate', 'ASC');
        } else if (query.sort === 'CUSTOMER_ASC') {
            qb.addSelect('LOWER(customer.name)', 'customer_name_sort').orderBy('customer_name_sort', 'ASC')
                .addOrderBy('receivable.dueDate', 'ASC');
        } else {
            qb.orderBy('receivable.dueDate', 'ASC')
                .addOrderBy('receivable.createdAt', 'ASC');
        }
        return qb.addOrderBy('receivable.id', 'ASC');
    }

    private async mapOpenReceivableRows(
        shopId: number,
        receivables: Receivable[],
        asOf: Date,
        manager: EntityManager,
        effects: OpeningBalanceEffects,
    ) {
        const orderIds = [
            ...new Set(
                receivables
                    .map((receivable) => Number(receivable.orderId))
                    .filter((id) => Number.isInteger(id) && id > 0),
            ),
        ];
        const orders = orderIds.length
            ? await manager.getRepository(SalesOrder).find({
                where: { shopId, id: In(orderIds) },
            })
            : [];
        const orderCodes = new Map(
            orders.map((order) => [order.id, order.orderCode]),
        );

        return receivables.map((receivable) => {
            const customer = receivable.customer?.shopId === shopId
                ? receivable.customer
                : undefined;
            const totalAmount = openingEffectValue(openingEffectCents(receivable.amount));
            const paidAmount = openingEffectValue(openingEffectCents(receivable.paidAmount || 0));
            const adjustment = effects.receivableCents.get(receivable.id) ?? 0n;
            const remaining = openingEffectValue(openingAdjustedDebt(receivable.amount, receivable.paidAmount, adjustment).remainingCents);
            const aging = classifyDebtAging(receivable.dueDate, asOf);
            return {
                id: receivable.id,
                customerId: customer?.id,
                customerName: customer?.name || 'Khách hàng',
                customerPhone: customer?.zaloPhone || customer?.phone || '',
                orderId: receivable.orderId,
                orderCode: orderCodes.get(Number(receivable.orderId)) ||
                    `CN-${receivable.id}`,
                createdAt: receivable.createdAt,
                dueDate: receivable.dueDate,
                totalAmount,
                paidAmount,
                remaining,
                openingAdjustmentAmount: openingEffectValue(adjustment),
                daysOverdue: aging.daysOverdue,
                status: aging.daysOverdue > 0 ? 'OVERDUE' : paidAmount > 0 ? 'PARTIAL' : 'UNPAID',
            };
        });
    }

    private async getOpenReceivableSummary(shopId: number, query: NormalizedReceivableListQuery,
        manager: EntityManager, effects: OpeningBalanceEffects, balanceAsOf: string) {
        const asOfDate = vietnamDateKey(query.asOf);
        const raw = await this.buildOpenReceivableQuery(shopId, { ...query, search: undefined, status: 'ALL', sort: 'DUE_DATE_ASC' }, manager, effects, balanceAsOf)
            .orderBy()
            .select(
                `COALESCE(SUM(${OPEN_RECEIVABLE_REMAINING}), 0)`,
                'outstanding',
            )
            .addSelect(
                `COALESCE(SUM(
                    CASE WHEN receivable.dueDate < :asOfDate
                    THEN ${OPEN_RECEIVABLE_REMAINING}
                    ELSE 0 END
                ), 0)`,
                'overdue',
            )
            .addSelect('COUNT(*)', 'receivableCount')
            .addSelect('COUNT(DISTINCT receivable.customer_id)', 'customerCount')
            .setParameter('asOfDate', asOfDate)
            .getRawOne();

        return {
            outstanding: openingEffectValue(openingEffectCents(raw?.outstanding || 0)),
            overdue: openingEffectValue(openingEffectCents(raw?.overdue || 0)),
            customerCount: Number(raw?.customerCount || 0),
            receivableCount: Number(raw?.receivableCount || 0),
        };
    }

    async getOpenReceivablesPage(
        shopId: number,
        input: ReceivableListQueryInput,
    ) {
        const query = normalizeReceivableListQuery(input);
        return this.withReceivableSnapshot(shopId, async (manager, effects, balanceAsOf) => {
            const qb = this.buildOpenReceivableQuery(shopId, query, manager, effects, balanceAsOf);
            const [receivables, total] = await qb.skip((query.page - 1) * query.limit).take(query.limit).getManyAndCount();
            const items = await this.mapOpenReceivableRows(shopId, receivables, query.asOf, manager, effects);
            const summary = await this.getOpenReceivableSummary(shopId, query, manager, effects, balanceAsOf);
            return {                
items, total, page: query.page, limit: query.limit, totalPages: Math.max(1, Math.ceil(total / query.limit)),
                summary, asOf: query.asOf, balanceAsOf, balanceBasis: 'CURRENT' as const            
};
        });
    }

    async exportOpenReceivables(
        shopId: number,
        input: ReceivableListQueryInput,
    ) {
        const query = normalizeReceivableListQuery(input);
        return this.withReceivableSnapshot(shopId, async (manager, effects, balanceAsOf) => {
            const records = await this.buildOpenReceivableQuery(shopId, query, manager, effects, balanceAsOf).getMany();
            return this.mapOpenReceivableRows(shopId, records, query.asOf, manager, effects);
        });
    }

    async getDebtEvidence(shopId: number, customerId: number) {
        return this.evidenceRepo.find({ where: { shopId, receivable: { customer: { id: customerId } } } });
    }

    async addDebtEvidence(
        shopId: number,
        receivableId: number,
        uploadedBy: number | undefined,
        dto: Partial<DebtEvidence>,
    ) {
        const type = String(dto.type || '').toUpperCase();
        const fileUrl = String(dto.fileUrl || '').trim();
        if (!['PHOTO', 'SIGNATURE', 'DOCUMENT', 'CONTRACT'].includes(type)) {
            throw new Error('Validation: Evidence type is invalid');
        }
        if (!fileUrl || fileUrl.length > 1000) {
            throw new Error('Validation: Evidence URL is required');
        }
        if (!debtEvidenceImageKeyFromPublicUrl(
            shopId,
            fileUrl,
            config.cloudinaryCloudName,
        )) {
            throw new Error('Validation: Evidence image is not owned by this shop');
        }
        const fileName = String(dto.fileName || '').trim();
        if (fileName.length > 200) {
            throw new Error('Validation: Evidence file name is too long');
        }
        const description = String(dto.description || '').trim();
        if (description.length > 500) {
            throw new Error('Validation: Evidence description is too long');
        }
        const fileSize = dto.fileSize == null ? undefined : Number(dto.fileSize);
        if (
            fileSize !== undefined &&
            (!Number.isInteger(fileSize) || fileSize <= 0 || fileSize > MAX_PRODUCT_IMAGE_BYTES)
        ) {
            throw new Error('Validation: Evidence file size is invalid');
        }
        const receivable = await this.receivableRepo.findOne({
            where: { id: receivableId, shopId },
        });
        if (!receivable) throw new Error('Receivable not found');
        return this.evidenceRepo.save(this.evidenceRepo.create({
            shopId,
            receivable,
            type,
            fileUrl,
            fileName: fileName || undefined,
            fileSize,
            description: description || undefined,
            uploadedBy,
        }));
    }

    async removeDebtEvidence(shopId: number, evidenceId: number) {
        const evidence = await this.evidenceRepo.findOne({
            where: { id: evidenceId, shopId },
        });
        if (!evidence) throw new Error('Debt evidence not found');

        await this.evidenceRepo.remove(evidence);
        try {
            await this.imageStorageService.deleteDebtEvidenceImageByUrl(
                shopId,
                evidence.fileUrl,
            );
        } catch {
            // Database state is authoritative; storage cleanup is best effort.
        }
        return { deleted: true };
    }

    async getDebtAging(shopId: number, asOf?: string) {
        const now = resolveVietnamBusinessDayEnd(asOf);
        const query = normalizeReceivableListQuery({ asOf });
        return this.withReceivableSnapshot(shopId, async (manager, effects, balanceAsOf) => {
            const receivables = await this.buildOpenReceivableQuery(shopId, query, manager, effects, balanceAsOf)
                .leftJoinAndSelect('receivable.paymentHistory', 'paymentHistory', '(paymentHistory.shopId = :shopId OR paymentHistory.shopId IS NULL)', { shopId })
                .getMany();
            const buckets = { current: 0n, past30: 0n, past60: 0n, past90: 0n };
            let totalDebtCents = 0n;
            let receivableCount = 0;
            const byCustomer = new Map<number, {
                customerId: number;
                customerName: string;
                total: bigint;
                current: bigint;
                past30: bigint;
                past60: bigint;
                past90: bigint;
                overdue: bigint;
                overdueDays: number;
                lastPaymentDate: Date | null;
            }>();

            for (const r of receivables) {
                const remaining = openingAdjustedDebt(r.amount, r.paidAmount, effects.receivableCents.get(r.id) ?? 0n).remainingCents;
                if (remaining <= 0n) continue;
                receivableCount += 1;
                totalDebtCents += remaining;

                const customerId = Number(r.customer?.id || 0);
                const customerName = r.customer?.name || 'N/A';
                if (!byCustomer.has(customerId)) {
                    byCustomer.set(customerId, {
                        customerId,
                        customerName,
                        total: 0n,
                        current: 0n,
                        past30: 0n,
                        past60: 0n,
                        past90: 0n,
                        overdue: 0n,
                        overdueDays: 0,
                        lastPaymentDate: null,
                    });
                }
                const customerBucket = byCustomer.get(customerId)!;
                customerBucket.total += remaining;

                const aging = classifyDebtAging(r.dueDate, now);
                buckets[aging.bucket] += remaining;
                customerBucket[aging.bucket] += remaining;
                if (aging.daysOverdue > 0) {
                    customerBucket.overdue += remaining;
                    customerBucket.overdueDays = Math.max(
                        customerBucket.overdueDays,
                        aging.daysOverdue,
                    );
                }

                if (Array.isArray(r.paymentHistory) && r.paymentHistory.length > 0) {
                    const lastPayment = r.paymentHistory
                        .map((p) => new Date(p.paymentDate))
                        .sort((a, b) => b.getTime() - a.getTime())[0];
                    if (!customerBucket.lastPaymentDate || lastPayment > customerBucket.lastPaymentDate) {
                        customerBucket.lastPaymentDate = lastPayment;
                    }
                }
            }

            const customers = Array.from(byCustomer.values())
                .sort((a, b) => a.overdue === b.overdue
                    ? a.total === b.total ? a.customerId - b.customerId : a.total > b.total ? -1 : 1
                    : a.overdue > b.overdue ? -1 : 1)
                .map((c) => ({
                    ...c,
                    total: openingEffectValue(c.total),
                    current: openingEffectValue(c.current),
                    past30: openingEffectValue(c.past30),
                    past60: openingEffectValue(c.past60),
                    past90: openingEffectValue(c.past90),
                    overdue: openingEffectValue(c.overdue),
                    lastPaymentDate: c.lastPaymentDate ? c.lastPaymentDate.toISOString() : null,
                }));

            const bucketValues = {
                current: openingEffectValue(buckets.current),
                past30: openingEffectValue(buckets.past30),
                past60: openingEffectValue(buckets.past60),
                past90: openingEffectValue(buckets.past90),
            };
            const totalDebt = openingEffectValue(totalDebtCents);
            const overdueDebt = openingEffectValue(buckets.past30 + buckets.past60 + buckets.past90);
            return {
                asOf: now,
                balanceAsOf,
                balanceBasis: 'CURRENT' as const,
                buckets: {
                    ...bucketValues,
                    // Backward-compatible aliases for old UI keys.
                    days30: bucketValues.past30,
                    days60: bucketValues.past60,
                    days90: bucketValues.past90,
                    over90: bucketValues.past90,
                },
                totalDebt,
                receivableCount,
                customerCount: customers.length,
                customers,
                summary: {
                    totalDebt,
                    overdueDebt,
                    receivableCount,
                    customerCount: customers.length,
                    currentRatio: totalDebt > 0 ? Number((bucketValues.current / totalDebt).toFixed(4)) : 0,
                    overdueRatio: totalDebt > 0 ? Number((overdueDebt / totalDebt).toFixed(4)) : 0,
                },
            };
        });
    }

    async getOverdueDebts(shopId: number) {
        const query = normalizeReceivableListQuery({ status: 'OVERDUE', sort: 'REMAINING_DESC' });
        return this.withReceivableSnapshot(shopId, async (manager, effects, balanceAsOf) => {
            const receivables = await this.buildOpenReceivableQuery(shopId, query, manager, effects, balanceAsOf).getMany();
            const rows = await this.mapOpenReceivableRows(shopId, receivables, query.asOf, manager, effects);
            return rows.map((r, index) => ({
                customerId: r.customerId,
                customerName: r.customerName,
                phone: receivables[index].customer?.phone || '',
                amount: r.totalAmount,
                paidAmount: r.paidAmount,
                remaining: r.remaining,
                openingAdjustmentAmount: r.openingAdjustmentAmount,
                dueDate: r.dueDate,
                daysOverdue: r.daysOverdue,
            }));
        });
    }

}
