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

    async getDebtAging() {
        const receivables = await this.receivableRepo.find({
            where: { status: Not(In(['PAID'])) },
            relations: ['customer'],
        });

        const now = new Date();
        const buckets = { current: 0, days30: 0, days60: 0, days90: 0, over90: 0 };
        let totalDebt = 0;

        for (const r of receivables) {
            const remaining = Number(r.amount) - Number(r.paidAmount);
            if (remaining <= 0) continue;
            totalDebt += remaining;
            const daysDiff = Math.floor((now.getTime() - new Date(r.dueDate).getTime()) / (1000 * 60 * 60 * 24));
            if (daysDiff <= 0) buckets.current += remaining;
            else if (daysDiff <= 30) buckets.days30 += remaining;
            else if (daysDiff <= 60) buckets.days60 += remaining;
            else if (daysDiff <= 90) buckets.days90 += remaining;
            else buckets.over90 += remaining;
        }

        return { buckets, totalDebt, receivableCount: receivables.length };
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
