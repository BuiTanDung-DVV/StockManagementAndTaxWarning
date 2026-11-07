import { vietnameseSearchExpression, vietnameseSearchParams } from '../common/vietnamese-search.utils';
import { AppDataSource } from '../config/db.config';
import { Supplier, Payable } from '../supplier/entities';
import { EntityManager, In } from 'typeorm';
import { resolveVietnamBusinessDayEnd, vietnamDateKey } from '../finance/finance-period.utils';
import { lockShopMutation } from '../utils/shop-mutation-lock';
import { readOpeningBalanceEffects, OpeningBalanceEffects, openingDebtEffectRows, openingAdjustedDebt, openingEffectCents, openingEffectValue } from '../finance/opening-balance-effects.repository';
import {
    classifyPayableAging,
    payableDaysOverdue,
} from '../supplier/payable-aging.utils';
import { normalizeSupplierInput } from '../party/party-input.utils';

const PAYABLE_REMAINING = '(payable.amount - COALESCE(payable.paidAmount, 0) + COALESCE(opening_effect.adjustment_amount, 0))';

export class SupplierService {
    private supplierRepo = AppDataSource.getRepository(Supplier);

    private async withPayableSnapshot<T>(shopId: number, work: (manager: EntityManager, effects: OpeningBalanceEffects, balanceAsOf: string) => Promise<T>) {
        const balanceAsOf = vietnamDateKey(new Date());
        return AppDataSource.transaction('REPEATABLE READ', async manager => {
            await manager.query('SET TRANSACTION READ ONLY');
            const effects = await readOpeningBalanceEffects(manager, { shopId, asOf: balanceAsOf, includeCash: false, receivableIds: [] });
            return work(manager, effects, balanceAsOf);
        });
    }

    private openPayableQuery(manager: EntityManager, shopId: number, effects: OpeningBalanceEffects, balanceAsOf: string) {
        return manager.getRepository(Payable).createQueryBuilder('payable')
            .innerJoin(Supplier, 'supplier', 'supplier.id = payable.supplierId AND supplier.shopId = :shopId', { shopId })
            .leftJoin('(SELECT * FROM jsonb_to_recordset(CAST(:openingDebtRows AS jsonb)) AS e(id integer,adjustment_amount numeric,opening_date date))',
                'opening_effect', 'opening_effect.id = payable.id', { openingDebtRows: JSON.stringify(openingDebtEffectRows(effects, 'PAYABLE')) })
            .where('payable.shopId = :shopId', { shopId })
            .andWhere('payable.status <> :cancelled', { cancelled: 'CANCELLED' })
            .andWhere(`${PAYABLE_REMAINING} > 0`)
            .andWhere('(opening_effect.opening_date IS NULL OR opening_effect.opening_date <= :balanceAsOf)', { balanceAsOf });
    }

    private async withSupplierBalances(manager: EntityManager, suppliers: Supplier[], shopId: number, effects: OpeningBalanceEffects, balanceAsOf: string) {
        if (!suppliers.length) return [];
        const rows = await this.openPayableQuery(manager, shopId, effects, balanceAsOf)
            .andWhere('payable.supplierId IN (:...ids)', { ids: suppliers.map(supplier => supplier.id) })
            .select('payable.supplierId', 'supplierId').addSelect(`SUM(${PAYABLE_REMAINING})`, 'balance')
            .groupBy('payable.supplierId').getRawMany();
        const balances = new Map(rows.map(row => [Number(row.supplierId), openingEffectValue(openingEffectCents(row.balance))]));
        return suppliers.map(supplier => ({ ...supplier, balance: balances.get(supplier.id) ?? 0, balanceAsOf, balanceBasis: 'CURRENT' as const }));
    }

    async balanceInTransaction(manager: EntityManager, supplier: Supplier, balanceAsOf: string) {
        if (!manager.queryRunner?.isTransactionActive) throw new Error('Supplier balance requires an active transaction');
        const effects = await readOpeningBalanceEffects(manager, { shopId: supplier.shopId, asOf: balanceAsOf, includeCash: false, receivableIds: [] });
        return (await this.withSupplierBalances(manager, [supplier], supplier.shopId, effects, balanceAsOf))[0].balance;
    }

    async findAll(shopId: number, page = 1, limit = 20, search?: string) {
        return this.withPayableSnapshot(shopId, async (manager, effects, balanceAsOf) => {
            const qb = manager.getRepository(Supplier).createQueryBuilder('s')
                .where('s.shop_id = :shopId AND s.is_active = :isActive', { shopId, isActive: true });
            if (search?.trim()) {
                qb.andWhere(
                    `(${vietnameseSearchExpression('s.name')} OR ${vietnameseSearchExpression('s.phone')} OR ${vietnameseSearchExpression('s.code')} OR ${vietnameseSearchExpression('s.taxCode')})`,
                    vietnameseSearchParams(search),
                );
            }
            const [items, total] = await qb.skip((page - 1) * limit).take(limit).orderBy('s.createdAt', 'DESC').addOrderBy('s.id', 'DESC').getManyAndCount();
            return { items: await this.withSupplierBalances(manager, items, shopId, effects, balanceAsOf), total, page, limit, totalPages: Math.ceil(total / limit) };
        });
    }

    async findById(shopId: number, id: number) {
        return this.withPayableSnapshot(shopId, async (manager, effects, balanceAsOf) => {
            const supplier = await manager.findOne(Supplier, { where: { id, shopId } });
            if (!supplier) throw new Error('Supplier not found');
            return (await this.withSupplierBalances(manager, [supplier], shopId, effects, balanceAsOf))[0];
        });
    }

    async create(shopId: number, dto: Partial<Supplier>) {
        return this.supplierRepo.save(this.supplierRepo.create({ ...normalizeSupplierInput(dto, true), shopId, code: 'SUP' + Date.now().toString().slice(-6) }));
    }

    async update(shopId: number, id: number, dto: Partial<Supplier>) {
        return this.changeSupplierProfile(shopId, id, normalizeSupplierInput(dto));
    }

    async remove(shopId: number, id: number) {
        return this.changeSupplierProfile(shopId, id, { isActive: false });
    }

    private async changeSupplierProfile(shopId: number, id: number, patch: Record<string, unknown>) {
        return AppDataSource.transaction(async manager => {
            await lockShopMutation(manager, shopId);
            if (!await manager.findOne(Supplier, { where: { id, shopId } })) throw new Error('Supplier not found');
            if (Object.keys(patch).length) await manager.update(Supplier, { id, shopId }, patch);
            const supplier = await manager.findOne(Supplier, { where: { id, shopId } });
            if (!supplier) throw new Error('Supplier not found');
            const balanceAsOf = vietnamDateKey(new Date());
            const effects = await readOpeningBalanceEffects(manager, { shopId, asOf: balanceAsOf, includeCash: false, receivableIds: [] });
            return (await this.withSupplierBalances(manager, [supplier], shopId, effects, balanceAsOf))[0];
        });
    }

    async getPayables(shopId: number, supplierId: number) {
        return this.withPayableSnapshot(shopId, async (manager, effects, balanceAsOf) => {
            const records = await manager.getRepository(Payable).createQueryBuilder('payable')
                .innerJoin(Supplier, 'supplier', 'supplier.id = payable.supplierId AND supplier.shopId = :shopId', { shopId })
                .where('payable.shopId = :shopId AND payable.supplierId = :supplierId', { shopId, supplierId })
                .orderBy('payable.createdAt', 'ASC').addOrderBy('payable.id', 'ASC').getMany();
            return records.map(payable => {
                const adjustment = effects.payableCents.get(payable.id) ?? 0n;
                const openingEffective = (effects.payableDates.get(payable.id) ?? '') <= balanceAsOf;
                const debt = openingEffective && payable.status !== 'CANCELLED' ? openingAdjustedDebt(payable.amount, payable.paidAmount, adjustment) : null;
                const remaining = openingEffectValue(debt?.remainingCents ?? 0n);
                return {
                    ...payable, remaining, remainingAmount: remaining, openingAdjustmentAmount: openingEffectValue(adjustment),
                    openingEffective, closedByAdjustment: debt?.closedByAdjustment ?? false, balanceAsOf, balanceBasis: 'CURRENT' as const
                };
            });
        });
    }

    async getPayablesAging(shopId: number, asOf?: string) {
        const now = resolveVietnamBusinessDayEnd(asOf);
        return this.withPayableSnapshot(shopId, async (manager, effects, balanceAsOf) => {
            const payables = await this.openPayableQuery(manager, shopId, effects, balanceAsOf)
                .orderBy('payable.dueDate', 'ASC').addOrderBy('payable.id', 'ASC').getMany();
            const supplierIds = [...new Set(payables.map((item) => Number(item.supplierId)).filter(Number.isInteger))];
            const suppliers = supplierIds.length > 0
                ? await manager.getRepository(Supplier).find({ where: { shopId, id: In(supplierIds) } })
                : [];
            const supplierById = new Map(suppliers.map((supplier) => [supplier.id, supplier]));
            const buckets = { current: 0n, past30: 0n, past60: 0n, past90: 0n };
            const bySupplier = new Map<number, {
                supplierId: number;
                supplierName: string;
                payableCount: number;
                totalOutstanding: bigint;
                overdueOutstanding: bigint;
                maxDaysOverdue: number;
                oldestDueDate: string | null;
            }>();
            const items: Array<Record<string, unknown>> = [];

            for (const payable of payables) {
                const adjustment = effects.payableCents.get(payable.id) ?? 0n;
                const remaining = openingAdjustedDebt(payable.amount, payable.paidAmount, adjustment).remainingCents;
                if (remaining <= 0n) continue;

                const bucket = classifyPayableAging(payable.dueDate, now);
                const daysOverdue = payableDaysOverdue(payable.dueDate, now);
                buckets[bucket] += remaining;

                const supplier = supplierById.get(Number(payable.supplierId));
                const supplierId = Number(payable.supplierId);
                const supplierSummary = bySupplier.get(supplierId) ?? {
                    supplierId,
                    supplierName: supplier?.name || 'Nhà cung cấp chưa xác định',
                    payableCount: 0,
                    totalOutstanding: 0n,
                    overdueOutstanding: 0n,
                    maxDaysOverdue: 0,
                    oldestDueDate: null,
                };
                supplierSummary.payableCount += 1;
                supplierSummary.totalOutstanding += remaining;
                if (bucket !== 'current') supplierSummary.overdueOutstanding += remaining;
                supplierSummary.maxDaysOverdue = Math.max(supplierSummary.maxDaysOverdue, daysOverdue);
                const dueDate = new Date(payable.dueDate).toISOString().slice(0, 10);
                if (!supplierSummary.oldestDueDate || dueDate < supplierSummary.oldestDueDate) {
                    supplierSummary.oldestDueDate = dueDate;
                }
                bySupplier.set(supplierId, supplierSummary);

                items.push({
                    id: payable.id,
                    createdAt: payable.createdAt,
                    supplierId,
                    supplierName: supplierSummary.supplierName,
                    purchaseOrderId: payable.purchaseOrderId,
                    amount: openingEffectValue(openingEffectCents(payable.amount)),
                    paidAmount: openingEffectValue(openingEffectCents(payable.paidAmount)),
                    remaining: openingEffectValue(remaining),
                    openingAdjustmentAmount: openingEffectValue(adjustment),
                    dueDate,
                    daysOverdue,
                    bucket,
                });
            }

            const totalOutstanding = openingEffectValue(buckets.current + buckets.past30 + buckets.past60 + buckets.past90);
            const overdueOutstanding = openingEffectValue(buckets.past30 + buckets.past60 + buckets.past90);
            const supplierSummaries = [...bySupplier.values()].sort(
                (a, b) => a.overdueOutstanding === b.overdueOutstanding
                    ? a.totalOutstanding === b.totalOutstanding ? a.supplierId - b.supplierId : a.totalOutstanding > b.totalOutstanding ? -1 : 1
                    : a.overdueOutstanding > b.overdueOutstanding ? -1 : 1,
            ).map(supplier => ({ ...supplier, totalOutstanding: openingEffectValue(supplier.totalOutstanding), overdueOutstanding: openingEffectValue(supplier.overdueOutstanding) }));
            items.sort((a, b) =>
                Number(b.daysOverdue) - Number(a.daysOverdue)
                || Number(b.remaining) - Number(a.remaining));

            return {
                asOf: now.toISOString(),
                balanceAsOf,
                balanceBasis: 'CURRENT' as const,
                buckets: {
                    current: openingEffectValue(buckets.current), past30: openingEffectValue(buckets.past30),
                    past60: openingEffectValue(buckets.past60), past90: openingEffectValue(buckets.past90)
                },
                summary: {
                    totalOutstanding,
                    overdueOutstanding,
                    overdueRatio: totalOutstanding > 0
                        ? Number((overdueOutstanding / totalOutstanding).toFixed(4))
                        : 0,
                    payableCount: items.length,
                    supplierCount: supplierSummaries.length,
                },
                suppliers: supplierSummaries,
                items,
            };
        });
    }

}
