import { AppDataSource } from '../config/db.config';
import { Customer, Receivable, DebtEvidence, DebtPaymentHistory } from '../customer/entities';
import { Not, In } from 'typeorm';

export class CustomerService {
    private customerRepo = AppDataSource.getRepository(Customer);
    private receivableRepo = AppDataSource.getRepository(Receivable);
    private evidenceRepo = AppDataSource.getRepository(DebtEvidence);
    private paymentRepo = AppDataSource.getRepository(DebtPaymentHistory);

    async findAll(page = 1, limit = 20, search?: string) {
        const qb = this.customerRepo.createQueryBuilder('c');
        if (search) {
            qb.where('c.name LIKE :s OR c.phone LIKE :s OR c.code LIKE :s', { s: `%${search}%` });
        }
        const [items, total] = await qb.skip((page - 1) * limit).take(limit).orderBy('c.createdAt', 'DESC').getManyAndCount();
        return { items, total, page, limit, totalPages: Math.ceil(total / limit) };
    }

    async findById(id: number) {
        const customer = await this.customerRepo.findOne({ where: { id } });
        if (!customer) throw new Error('Customer not found');
        return customer;
    }

    async create(dto: Partial<Customer>) {
        return this.customerRepo.save(this.customerRepo.create({ ...dto, code: 'CUS' + Date.now().toString().slice(-6) }));
    }

    async update(id: number, dto: Partial<Customer>) {
        const customer = await this.findById(id);
        Object.assign(customer, dto);
        return this.customerRepo.save(customer);
    }

    async remove(id: number) {
        const customer = await this.findById(id);
        customer.isActive = false;
        return this.customerRepo.save(customer);
    }

    async getReceivables(customerId: number) {
        return this.receivableRepo.find({ where: { customer: { id: customerId } }, relations: ['evidences', 'paymentHistory'] });
    }

    async getDebtEvidence(customerId: number) {
        return this.evidenceRepo.find({ where: { receivable: { customer: { id: customerId } } } });
    }

    async addPayment(customerId: number, receivableId: number, dto: Partial<DebtPaymentHistory>) {
        const receivable = await this.receivableRepo.findOne({ where: { id: receivableId, customer: { id: customerId } } });
        if (!receivable) throw new Error('Receivable not found');
        return this.paymentRepo.save(this.paymentRepo.create({ ...dto, receivable }));
    }

    async getDebtAging(asOf?: string) {
        const receivables = await this.receivableRepo.find({
            where: { status: Not(In(['PAID'])) },
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

    async getOverdueDebts() {
        const receivables = await this.receivableRepo.find({
            where: { status: Not(In(['PAID'])) },
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
}
