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
import { Not, In } from 'typeorm';
import { SalesOrder } from '../sales/entities';
import { calculateRemainingDebt } from '../customer/debt.utils';
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

export class CustomerService {
    private customerRepo = AppDataSource.getRepository(Customer);
    private receivableRepo = AppDataSource.getRepository(Receivable);
    private evidenceRepo = AppDataSource.getRepository(DebtEvidence);
    private imageStorageService = new ImageStorageService();
    private orderRepo = AppDataSource.getRepository(SalesOrder);
    private financeService = new FinanceService();
    private postingService = new PostingService();

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
        return this.customerRepo.save(this.customerRepo.create({ ...normalizeCustomerInput(dto, true), shopId, code: 'CUS' + Date.now().toString().slice(-6) }));
    }

    async update(shopId: number, id: number, dto: Partial<Customer>) {
        const customer = await this.findById(shopId, id);
        Object.assign(customer, normalizeCustomerInput(dto));
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

    async collectManualReceivablePayment(
        shopId: number,
        receivableId: number,
        recordedBy: number | undefined,
        dto: { amount?: unknown; method?: unknown; notes?: unknown },
    ) {
        const amount = Number(dto.amount);
        if (!Number.isFinite(amount) || amount <= 0) {
            throw new Error('Validation: Payment amount must be greater than 0');
        }
        const paymentMethod = normalizeSettledPaymentMethod(
            String(dto.method || 'CASH'),
        );
        const notes = String(dto.notes || '').trim();
        if (notes.length > 500) {
            throw new Error('Validation: Notes must not exceed 500 characters');
        }

        return AppDataSource.transaction(async (manager) => {
            const receivable = await manager.findOne(Receivable, {
                where: { id: receivableId, shopId },
                relations: ['customer'],
                lock: { mode: 'pessimistic_write' },
            });
            if (!receivable) throw new Error('Receivable not found');
            if (receivable.status === 'PAID' || receivable.status === 'CANCELLED') {
                throw new Error('Validation: Receivable is already closed');
            }
            if (Number(receivable.orderId) > 0) {
                throw new Error(
                    'Validation: Linked receivable must use the sales order payment workflow',
                );
            }

            const payment = calculateRemainingDebt(
                Number(receivable.amount),
                Number(receivable.paidAmount || 0),
            );
            if (amount > payment) {
                throw new Error(
                    'Validation: Payment amount exceeds remaining receivable balance',
                );
            }

            receivable.paidAmount = Number(receivable.paidAmount || 0) + amount;
            const remaining = calculateRemainingDebt(
                Number(receivable.amount),
                Number(receivable.paidAmount),
            );
            receivable.status = remaining === 0 ? 'PAID' : 'PARTIAL';
            await manager.save(Receivable, receivable);

            const history = await manager.save(
                DebtPaymentHistory,
                manager.create(DebtPaymentHistory, {
                    shopId,
                    receivable,
                    amount,
                    paymentMethod,
                    paymentDate: new Date(),
                    notes: notes || undefined,
                    recordedBy,
                }),
            );

            const customer = receivable.customer?.shopId === shopId
                ? receivable.customer
                : undefined;
            if (!customer) throw new Error('Customer not found');
            customer.balance = Math.max(
                Number(customer.balance || 0) - amount,
                0,
            );
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
                transactionDate: new Date(),
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
            );

            return {
                receivableId: receivable.id,
                paymentHistoryId: history.id,
                paidAmount: Number(receivable.paidAmount),
                remaining,
                status: receivable.status,
            };
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

    private buildOpenReceivableQuery(
        shopId: number,
        query: NormalizedReceivableListQuery,
    ) {
        const asOfDate = vietnamDateKey(query.asOf);
        const qb = this.receivableRepo.createQueryBuilder('receivable')
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
            .where('receivable.shopId = :shopId', { shopId })
            .andWhere('receivable.status NOT IN (:...closedStatuses)', {
                closedStatuses: ['PAID', 'CANCELLED'],
            })
            .andWhere(
                '(receivable.amount - COALESCE(receivable.paidAmount, 0)) > 0',
            );

        if (query.search) {
            qb.andWhere(
                `(
                    customer.name ILIKE :search OR
                    customer.phone ILIKE :search OR
                    customer.zaloPhone ILIKE :search OR
                    customer.code ILIKE :search OR
                    salesOrder.orderCode ILIKE :search
                )`,
                { search: `%${query.search}%` },
            );
        }
        if (query.status === 'OVERDUE') {
            qb.andWhere('receivable.dueDate < :asOfDate', { asOfDate });
        } else if (query.status === 'CURRENT') {
            qb.andWhere('receivable.dueDate >= :asOfDate', { asOfDate });
        }

        if (query.sort === 'REMAINING_DESC') {
            qb.orderBy(
                '(receivable.amount - COALESCE(receivable.paidAmount, 0))',
                'DESC',
            ).addOrderBy('receivable.dueDate', 'ASC');
        } else if (query.sort === 'CUSTOMER_ASC') {
            qb.orderBy('LOWER(customer.name)', 'ASC')
                .addOrderBy('receivable.dueDate', 'ASC');
        } else {
            qb.orderBy('receivable.dueDate', 'ASC')
                .addOrderBy('receivable.createdAt', 'ASC');
        }
        return qb;
    }

    private async mapOpenReceivableRows(
        shopId: number,
        receivables: Receivable[],
        asOf: Date,
    ) {
        const orderIds = [
            ...new Set(
                receivables
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

        return receivables.map((receivable) => {
            const customer = receivable.customer?.shopId === shopId
                ? receivable.customer
                : undefined;
            const totalAmount = Number(receivable.amount);
            const paidAmount = Number(receivable.paidAmount || 0);
            const remaining = calculateRemainingDebt(totalAmount, paidAmount);
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
                daysOverdue: aging.daysOverdue,
                status: aging.daysOverdue > 0 ? 'OVERDUE' : receivable.status,
            };
        });
    }

    private async getOpenReceivableSummary(shopId: number, asOf: Date) {
        const asOfDate = vietnamDateKey(asOf);
        const raw = await this.receivableRepo.createQueryBuilder('receivable')
            .select(
                'COALESCE(SUM(receivable.amount - COALESCE(receivable.paidAmount, 0)), 0)',
                'outstanding',
            )
            .addSelect(
                `COALESCE(SUM(
                    CASE WHEN receivable.dueDate < :asOfDate
                    THEN receivable.amount - COALESCE(receivable.paidAmount, 0)
                    ELSE 0 END
                ), 0)`,
                'overdue',
            )
            .addSelect('COUNT(*)', 'receivableCount')
            .addSelect('COUNT(DISTINCT receivable.customer)', 'customerCount')
            .where('receivable.shopId = :shopId', { shopId })
            .andWhere('receivable.status NOT IN (:...closedStatuses)', {
                closedStatuses: ['PAID', 'CANCELLED'],
            })
            .andWhere(
                '(receivable.amount - COALESCE(receivable.paidAmount, 0)) > 0',
            )
            .setParameter('asOfDate', asOfDate)
            .getRawOne();

        return {
            outstanding: Number(raw?.outstanding || 0),
            overdue: Number(raw?.overdue || 0),
            customerCount: Number(raw?.customerCount || 0),
            receivableCount: Number(raw?.receivableCount || 0),
        };
    }

    async getOpenReceivablesPage(
        shopId: number,
        input: ReceivableListQueryInput,
    ) {
        const query = normalizeReceivableListQuery(input);
        const qb = this.buildOpenReceivableQuery(shopId, query);
        const [receivables, total] = await qb
            .skip((query.page - 1) * query.limit)
            .take(query.limit)
            .getManyAndCount();
        const [items, summary] = await Promise.all([
            this.mapOpenReceivableRows(shopId, receivables, query.asOf),
            this.getOpenReceivableSummary(shopId, query.asOf),
        ]);
        return {
            items,
            total,
            page: query.page,
            limit: query.limit,
            totalPages: Math.max(1, Math.ceil(total / query.limit)),
            summary,
            asOf: query.asOf,
        };
    }

    async exportOpenReceivables(
        shopId: number,
        input: ReceivableListQueryInput,
    ) {
        const query = normalizeReceivableListQuery(input);
        const receivables = await this.buildOpenReceivableQuery(shopId, query)
            .getMany();
        return this.mapOpenReceivableRows(shopId, receivables, query.asOf);
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
        const receivables = await this.receivableRepo.find({
            where: { shopId, status: Not(In(['PAID', 'CANCELLED'])) },
            relations: ['customer', 'paymentHistory'],
        });

        const now = resolveVietnamBusinessDayEnd(asOf);

        const buckets = { current: 0, past30: 0, past60: 0, past90: 0 };
        let totalDebt = 0;
        let receivableCount = 0;
        const byCustomer = new Map<number, {
            customerId: number;
            customerName: string;
            total: number;
            current: number;
            past30: number;
            past60: number;
            past90: number;
            overdue: number;
            overdueDays: number;
            lastPaymentDate: Date | null;
        }>();

        for (const r of receivables) {
            const remaining = calculateRemainingDebt(Number(r.amount), Number(r.paidAmount));
            if (remaining <= 0) continue;
            receivableCount += 1;
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
                    overdue: 0,
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
            .sort((a, b) => b.overdue - a.overdue || b.total - a.total)
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
            receivableCount,
            customerCount: customers.length,
            customers,
            summary: {
                totalDebt,
                overdueDebt,
                receivableCount,
                customerCount: customers.length,
                currentRatio: totalDebt > 0 ? Number((buckets.current / totalDebt).toFixed(4)) : 0,
                overdueRatio: totalDebt > 0 ? Number((overdueDebt / totalDebt).toFixed(4)) : 0,
            },
        };
    }

    async getOverdueDebts(shopId: number) {
        const receivables = await this.receivableRepo.find({
            where: { shopId, status: Not(In(['PAID', 'CANCELLED'])) },
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
