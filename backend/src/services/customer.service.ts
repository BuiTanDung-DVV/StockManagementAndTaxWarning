import { AppDataSource } from '../config/db.config';
import { Customer, Receivable, DebtEvidence } from '../customer/entities';
import { Not, In } from 'typeorm';
import { SalesOrder } from '../sales/entities';
import { calculateRemainingDebt } from '../customer/debt.utils';

export class CustomerService {
    private customerRepo = AppDataSource.getRepository(Customer);
    private receivableRepo = AppDataSource.getRepository(Receivable);
    private evidenceRepo = AppDataSource.getRepository(DebtEvidence);
    private orderRepo = AppDataSource.getRepository(SalesOrder);

    async findAll(shopId: number, page = 1, limit = 20, search?: string) {
        const qb = this.customerRepo.createQueryBuilder('c')
            .where('c.shopId = :shopId AND c.isActive = :isActive', { shopId, isActive: true });
        if (search) {
            qb.andWhere('(c.name LIKE :s OR c.phone LIKE :s OR c.code LIKE :s)', { s: `%${search}%` });
        }
        const [items, total] = await qb.skip((page - 1) * limit).take(limit).orderBy('c.createdAt', 'DESC').getManyAndCount();
        return { items, total, page, limit, totalPages: Math.ceil(total / limit) };
    }

    async findById(shopId: number, id: number) {
        const customer = await this.customerRepo.findOne({ where: { id, shopId } });
        if (!customer) throw new Error('Customer not found');
        return customer;
    }

    async create(shopId: number, dto: Partial<Customer>) {
        return this.customerRepo.save(this.customerRepo.create({ ...this.normalizeCustomerDto(dto), shopId, code: 'CUS' + Date.now().toString().slice(-6) }));
    }

    async update(shopId: number, id: number, dto: Partial<Customer>) {
        const customer = await this.findById(shopId, id);
        Object.assign(customer, this.normalizeCustomerDto(dto));
        return this.customerRepo.save(customer);
    }

    async remove(shopId: number, id: number) {
        const customer = await this.findById(shopId, id);
        customer.isActive = false;
        return this.customerRepo.save(customer);
    }

    async getReceivables(shopId: number, customerId: number) {
        return this.receivableRepo.find({ where: { shopId, customer: { id: customerId } }, relations: ['evidences', 'paymentHistory'] });
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

    async getOpenReceivables(shopId: number) {
        const receivables = await this.receivableRepo.find({
            where: {
                shopId,
                status: Not(In(['PAID', 'CANCELLED'])),
            },
            relations: ['customer'],
            order: { dueDate: 'ASC', createdAt: 'ASC' },
        });

        const openReceivables = receivables.filter(
            (receivable) =>
                calculateRemainingDebt(
                    Number(receivable.amount),
                    Number(receivable.paidAmount),
                ) > 0,
        );
        const orderIds = [
            ...new Set(
                openReceivables
                    .map((receivable) => Number(receivable.orderId))
                    .filter((id) => Number.isInteger(id) && id > 0),
            ),
        ];
        const orders = orderIds.length
            ? await this.orderRepo.find({
                where: { shopId, id: In(orderIds) },
            })
            : [];
        const orderCodes = new Map(
            orders.map((order) => [order.id, order.orderCode]),
        );
        const now = new Date();

        return openReceivables.map((receivable) => {
            const customer =
                receivable.customer?.shopId === shopId
                    ? receivable.customer
                    : undefined;
            const totalAmount = Number(receivable.amount);
            const paidAmount = Number(receivable.paidAmount);
            const remaining = calculateRemainingDebt(totalAmount, paidAmount);
            const dueDate = new Date(receivable.dueDate);
            const daysOverdue = dueDate < now
                ? Math.floor(
                    (now.getTime() - dueDate.getTime()) /
                    (1000 * 60 * 60 * 24),
                )
                : 0;

            return {
                id: receivable.id,
                customerId: customer?.id,
                customerName: customer?.name || 'Khách hàng',
                customerPhone:
                    customer?.zaloPhone || customer?.phone || '',
                orderId: receivable.orderId,
                orderCode:
                    orderCodes.get(Number(receivable.orderId)) ||
                    `CN-${receivable.id}`,
                createdAt: receivable.createdAt,
                dueDate: receivable.dueDate,
                totalAmount,
                paidAmount,
                remaining,
                daysOverdue,
                status: daysOverdue > 0 ? 'OVERDUE' : receivable.status,
            };
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
        if (!['PHOTO', 'SIGNATURE', 'AUDIO', 'DOCUMENT', 'CONTRACT'].includes(type)) {
            throw new Error('Validation: Evidence type is invalid');
        }
        if (!fileUrl || fileUrl.length > 1000) {
            throw new Error('Validation: Evidence URL is required');
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
            fileName: dto.fileName,
            fileSize: dto.fileSize,
            description: dto.description,
            uploadedBy,
        }));
    }

    async getDebtAging(shopId: number, asOf?: string) {
        const receivables = await this.receivableRepo.find({
            where: { shopId, status: Not(In(['PAID'])) },
            relations: ['customer', 'paymentHistory'],
        });

        const now = asOf ? new Date(asOf) : new Date();
        now.setHours(23, 59, 59, 999);

        const buckets = { current: 0, past30: 0, past60: 0, past90: 0 };
        let totalDebt = 0;
        const byCustomer = new Map<number, {
            customerId: number;
            customerName: string;
            total: number;
            current: number;
            past30: number;
            past60: number;
            past90: number;
            overdueDays: number;
            lastPaymentDate: Date | null;
        }>();

        for (const r of receivables) {
            const remaining = Number(r.amount) - Number(r.paidAmount);
            if (remaining <= 0) continue;
            totalDebt += remaining;

            const customerId = Number(r.customer?.id || 0);
            const customerName = r.customer?.name || 'N/A';
            if (!byCustomer.has(customerId)) {
                byCustomer.set(customerId, {
                    customerId,
                    customerName,
                    total: 0,
                    current: 0,
                    past30: 0,
                    past60: 0,
                    past90: 0,
                    overdueDays: 0,
                    lastPaymentDate: null,
                });
            }
            const customerBucket = byCustomer.get(customerId)!;
            customerBucket.total += remaining;

            const daysDiff = Math.floor((now.getTime() - new Date(r.dueDate).getTime()) / (1000 * 60 * 60 * 24));
            if (daysDiff <= 0) {
                buckets.current += remaining;
                customerBucket.current += remaining;
            } else if (daysDiff <= 30) {
                buckets.past30 += remaining;
                customerBucket.past30 += remaining;
                customerBucket.overdueDays = Math.max(customerBucket.overdueDays, daysDiff);
            } else if (daysDiff <= 60) {
                buckets.past60 += remaining;
                customerBucket.past60 += remaining;
                customerBucket.overdueDays = Math.max(customerBucket.overdueDays, daysDiff);
            } else {
                buckets.past90 += remaining;
                customerBucket.past90 += remaining;
                customerBucket.overdueDays = Math.max(customerBucket.overdueDays, daysDiff);
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
            .sort((a, b) => b.total - a.total)
            .map((c) => ({
                ...c,
                lastPaymentDate: c.lastPaymentDate ? c.lastPaymentDate.toISOString() : null,
            }));

        const overdueDebt = buckets.past30 + buckets.past60 + buckets.past90;
        return {
            asOf: now,
            buckets: {
                ...buckets,
                // Backward-compatible aliases for old UI keys.
                days30: buckets.past30,
                days60: buckets.past60,
                days90: buckets.past90,
                over90: buckets.past90,
            },
            totalDebt,
            receivableCount: receivables.length,
            customers,
            summary: {
                totalDebt,
                currentRatio: totalDebt > 0 ? Number((buckets.current / totalDebt).toFixed(4)) : 0,
                overdueRatio: totalDebt > 0 ? Number((overdueDebt / totalDebt).toFixed(4)) : 0,
            },
        };
    }

    async getOverdueDebts(shopId: number) {
        const receivables = await this.receivableRepo.find({
            where: { shopId, status: Not(In(['PAID'])) },
            relations: ['customer'],
            order: { dueDate: 'ASC' },
        });

        const now = new Date();
        const overdueItems = receivables
            .filter(r => new Date(r.dueDate) < now && (Number(r.amount) - Number(r.paidAmount)) > 0)
            .map(r => ({
                customerId: r.customer?.id,
                customerName: r.customer?.name || 'N/A',
                phone: r.customer?.phone || '',
                amount: Number(r.amount),
                paidAmount: Number(r.paidAmount),
                remaining: Number(r.amount) - Number(r.paidAmount),
                dueDate: r.dueDate,
                daysOverdue: Math.floor((now.getTime() - new Date(r.dueDate).getTime()) / (1000 * 60 * 60 * 24)),
            }))
            .sort((a, b) => b.remaining - a.remaining);

        return overdueItems;
    }

    private normalizeCustomerDto(dto: any) {
        const normalized = { ...dto };
        if (normalized.notes === undefined && normalized.note !== undefined) {
            normalized.notes = normalized.note;
        }
        delete normalized.note;
        return normalized;
    }
}
