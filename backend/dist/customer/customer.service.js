"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.CustomerService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const entities_1 = require("./entities");
let CustomerService = class CustomerService {
    constructor(customerRepo, receivableRepo, evidenceRepo, paymentRepo) {
        this.customerRepo = customerRepo;
        this.receivableRepo = receivableRepo;
        this.evidenceRepo = evidenceRepo;
        this.paymentRepo = paymentRepo;
    }
    async findAll(page = 1, limit = 20, search) {
        const where = search ? [{ name: (0, typeorm_2.Like)(`%${search}%`) }, { phone: (0, typeorm_2.Like)(`%${search}%`) }, { code: (0, typeorm_2.Like)(`%${search}%`) }] : {};
        const [items, total] = await this.customerRepo.findAndCount({
            where, skip: (page - 1) * limit, take: limit, order: { createdAt: 'DESC' },
        });
        return { items, total, page, limit, totalPages: Math.ceil(total / limit) };
    }
    async findById(id) {
        const c = await this.customerRepo.findOne({ where: { id } });
        if (!c)
            throw new common_1.NotFoundException('Customer not found');
        return c;
    }
    async create(dto) {
        if (!dto.code)
            dto.code = 'KH' + Date.now().toString().slice(-6);
        return this.customerRepo.save(this.customerRepo.create(dto));
    }
    async update(id, dto) {
        const c = await this.findById(id);
        Object.assign(c, dto);
        return this.customerRepo.save(c);
    }
    async findReceivables(customerId) {
        return this.receivableRepo.find({ where: { customer: { id: customerId } }, relations: ['evidences', 'paymentHistory'], order: { createdAt: 'DESC' } });
    }
    async createReceivable(customerId, dto) {
        const customer = await this.findById(customerId);
        return this.receivableRepo.save(this.receivableRepo.create({ ...dto, customer }));
    }
    async addEvidence(receivableId, dto) {
        const receivable = await this.receivableRepo.findOne({ where: { id: receivableId } });
        if (!receivable)
            throw new common_1.NotFoundException('Receivable not found');
        return this.evidenceRepo.save(this.evidenceRepo.create({ ...dto, receivable }));
    }
    async addPayment(receivableId, dto) {
        const receivable = await this.receivableRepo.findOne({ where: { id: receivableId } });
        if (!receivable)
            throw new common_1.NotFoundException('Receivable not found');
        const payment = await this.paymentRepo.save(this.paymentRepo.create({ ...dto, receivable }));
        receivable.paidAmount = Number(receivable.paidAmount) + Number(dto.amount);
        if (receivable.paidAmount >= Number(receivable.amount)) {
            receivable.status = 'PAID';
        }
        else {
            receivable.status = 'PARTIAL';
        }
        await this.receivableRepo.save(receivable);
        return payment;
    }
    async findOverdueDebts() {
        return this.receivableRepo.createQueryBuilder('r')
            .leftJoinAndSelect('r.customer', 'c')
            .where('r.status != :paid', { paid: 'PAID' })
            .andWhere('r.dueDate < :now', { now: new Date() })
            .orderBy('r.dueDate', 'ASC')
            .getMany();
    }
    async getDebtAging() {
        const now = new Date();
        const receivables = await this.receivableRepo.createQueryBuilder('r')
            .leftJoinAndSelect('r.customer', 'c')
            .where('r.status != :paid', { paid: 'PAID' })
            .getMany();
        const aging = {
            current: [],
            days_1_30: [],
            days_31_60: [],
            days_61_90: [],
            days_over_90: [],
        };
        let totalCurrentAmount = 0, total30 = 0, total60 = 0, total90 = 0, totalOver90 = 0;
        for (const r of receivables) {
            const remaining = Number(r.amount) - Number(r.paidAmount);
            const daysOverdue = Math.floor((now.getTime() - new Date(r.dueDate).getTime()) / (1000 * 60 * 60 * 24));
            const entry = {
                receivableId: r.id,
                customerName: r.customer?.name || 'N/A',
                amount: Number(r.amount),
                paidAmount: Number(r.paidAmount),
                remaining,
                dueDate: r.dueDate,
                daysOverdue: Math.max(0, daysOverdue),
            };
            if (daysOverdue <= 0) {
                aging.current.push(entry);
                totalCurrentAmount += remaining;
            }
            else if (daysOverdue <= 30) {
                aging.days_1_30.push(entry);
                total30 += remaining;
            }
            else if (daysOverdue <= 60) {
                aging.days_31_60.push(entry);
                total60 += remaining;
            }
            else if (daysOverdue <= 90) {
                aging.days_61_90.push(entry);
                total90 += remaining;
            }
            else {
                aging.days_over_90.push(entry);
                totalOver90 += remaining;
            }
        }
        return {
            summary: {
                totalOutstanding: totalCurrentAmount + total30 + total60 + total90 + totalOver90,
                current: totalCurrentAmount,
                overdue_1_30: total30,
                overdue_31_60: total60,
                overdue_61_90: total90,
                overdue_over_90: totalOver90,
            },
            aging,
        };
    }
};
exports.CustomerService = CustomerService;
exports.CustomerService = CustomerService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(entities_1.Customer)),
    __param(1, (0, typeorm_1.InjectRepository)(entities_1.Receivable)),
    __param(2, (0, typeorm_1.InjectRepository)(entities_1.DebtEvidence)),
    __param(3, (0, typeorm_1.InjectRepository)(entities_1.DebtPaymentHistory)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository])
], CustomerService);
//# sourceMappingURL=customer.service.js.map