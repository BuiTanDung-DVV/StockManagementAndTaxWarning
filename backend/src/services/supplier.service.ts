import { AppDataSource } from '../config/db.config';
import { Supplier, Payable } from '../supplier/entities';
import { In, Not } from 'typeorm';
import { resolveVietnamBusinessDayEnd } from '../finance/finance-period.utils';
import {
    calculateRemainingPayable,
    classifyPayableAging,
    payableDaysOverdue,
} from '../supplier/payable-aging.utils';

export class SupplierService {
    private supplierRepo = AppDataSource.getRepository(Supplier);
    private payableRepo = AppDataSource.getRepository(Payable);

    async findAll(shopId: number, page = 1, limit = 20, search?: string) {
        const qb = this.supplierRepo.createQueryBuilder('s')
            .where('s.shop_id = :shopId AND s.is_active = :isActive', { shopId, isActive: true });
        if (search) {
            qb.andWhere('(s.name LIKE :s OR s.phone LIKE :s OR s.code LIKE :s)', { s: `%${search}%` });
        }
        const [items, total] = await qb.skip((page - 1) * limit).take(limit).orderBy('s.createdAt', 'DESC').getManyAndCount();
        return { items, total, page, limit, totalPages: Math.ceil(total / limit) };
    }

    async findById(shopId: number, id: number) {
        const supplier = await this.supplierRepo.findOne({ where: { id, shopId } });
        if (!supplier) throw new Error('Supplier not found');
        return supplier;
    }

    async create(shopId: number, dto: Partial<Supplier>) {
        return this.supplierRepo.save(this.supplierRepo.create({ ...this.normalizeSupplierDto(dto), shopId, code: 'SUP' + Date.now().toString().slice(-6) }));
    }

    async update(shopId: number, id: number, dto: Partial<Supplier>) {
        const supplier = await this.findById(shopId, id);
        Object.assign(supplier, this.normalizeSupplierDto(dto));
        return this.supplierRepo.save(supplier);
    }

    async remove(shopId: number, id: number) {
        const supplier = await this.findById(shopId, id);
        supplier.isActive = false;
        return this.supplierRepo.save(supplier);
    }

    async getPayables(shopId: number, supplierId: number) {
        return this.payableRepo.find({ where: { shopId, supplierId } });
    }

    async getPayablesAging(shopId: number, asOf?: string) {
        const payables = await this.payableRepo.find({
            where: { shopId, status: Not(In(['PAID', 'CANCELLED'])) },
            order: { dueDate: 'ASC', id: 'ASC' },
        });
        const supplierIds = [...new Set(payables.map((item) => Number(item.supplierId)).filter(Number.isInteger))];
        const suppliers = supplierIds.length > 0
            ? await this.supplierRepo.find({ where: { shopId, id: In(supplierIds) } })
            : [];
        const supplierById = new Map(suppliers.map((supplier) => [supplier.id, supplier]));
        const now = resolveVietnamBusinessDayEnd(asOf);
        const buckets = { current: 0, past30: 0, past60: 0, past90: 0 };
        const bySupplier = new Map<number, {
            supplierId: number;
            supplierName: string;
            payableCount: number;
            totalOutstanding: number;
            overdueOutstanding: number;
            maxDaysOverdue: number;
            oldestDueDate: string | null;
        }>();
        const items: Array<Record<string, unknown>> = [];

        for (const payable of payables) {
            const remaining = calculateRemainingPayable(payable.amount, payable.paidAmount);
            if (remaining <= 0) continue;

            const bucket = classifyPayableAging(payable.dueDate, now);
            const daysOverdue = payableDaysOverdue(payable.dueDate, now);
            buckets[bucket] += remaining;

            const supplier = supplierById.get(Number(payable.supplierId));
            const supplierId = Number(payable.supplierId);
            const supplierSummary = bySupplier.get(supplierId) ?? {
                supplierId,
                supplierName: supplier?.name || 'Nhà cung cấp chưa xác định',
                payableCount: 0,
                totalOutstanding: 0,
                overdueOutstanding: 0,
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
                supplierId,
                supplierName: supplierSummary.supplierName,
                purchaseOrderId: payable.purchaseOrderId,
                amount: Number(payable.amount),
                paidAmount: Number(payable.paidAmount),
                remaining,
                dueDate,
                daysOverdue,
                bucket,
            });
        }

        const totalOutstanding = buckets.current + buckets.past30 + buckets.past60 + buckets.past90;
        const overdueOutstanding = buckets.past30 + buckets.past60 + buckets.past90;
        const supplierSummaries = [...bySupplier.values()].sort(
            (a, b) => b.overdueOutstanding - a.overdueOutstanding || b.totalOutstanding - a.totalOutstanding,
        );
        items.sort((a, b) =>
            Number(b.daysOverdue) - Number(a.daysOverdue)
            || Number(b.remaining) - Number(a.remaining));

        return {
            asOf: now.toISOString(),
            buckets,
            summary: {
                totalOutstanding,
                overdueOutstanding,
                overdueRatio: totalOutstanding > 0
                    ? Number((overdueOutstanding / totalOutstanding).toFixed(4))
                    : 0,
                payableCount: items.length,
                supplierCount: supplierSummaries.length,
            },
            suppliers: supplierSummaries.slice(0, 10),
            items: items.slice(0, 20),
        };
    }

    private normalizeSupplierDto(dto: any) {
        const normalized = { ...dto };
        if (normalized.notes === undefined && normalized.note !== undefined) {
            normalized.notes = normalized.note;
        }
        if (normalized.contactPerson === undefined && normalized.contactName !== undefined) {
            normalized.contactPerson = normalized.contactName;
        }
        delete normalized.note;
        delete normalized.contactName;
        return normalized;
    }
}
