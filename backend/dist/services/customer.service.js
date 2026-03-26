"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.CustomerService = void 0;
const db_config_1 = require("../config/db.config");
const entities_1 = require("../customer/entities");
class CustomerService {
    constructor() {
        this.customerRepo = db_config_1.AppDataSource.getRepository(entities_1.Customer);
        this.receivableRepo = db_config_1.AppDataSource.getRepository(entities_1.Receivable);
        this.evidenceRepo = db_config_1.AppDataSource.getRepository(entities_1.DebtEvidence);
        this.paymentRepo = db_config_1.AppDataSource.getRepository(entities_1.DebtPaymentHistory);
    }
    async findAll(page = 1, limit = 20, search) {
        const qb = this.customerRepo.createQueryBuilder('c');
        if (search) {
            qb.where('c.name LIKE :s OR c.phone LIKE :s OR c.code LIKE :s', { s: `%${search}%` });
        }
        const [items, total] = await qb.skip((page - 1) * limit).take(limit).orderBy('c.createdAt', 'DESC').getManyAndCount();
        return { items, total, page, limit, totalPages: Math.ceil(total / limit) };
    }
    async findById(id) {
        const customer = await this.customerRepo.findOne({ where: { id } });
        if (!customer)
            throw new Error('Customer not found');
        return customer;
    }
    async create(dto) {
        return this.customerRepo.save(this.customerRepo.create({ ...dto, code: 'CUS' + Date.now().toString().slice(-6) }));
    }
    async update(id, dto) {
        const customer = await this.findById(id);
        Object.assign(customer, dto);
        return this.customerRepo.save(customer);
    }
    async remove(id) {
        const customer = await this.findById(id);
        customer.isActive = false;
        return this.customerRepo.save(customer);
    }
    async getReceivables(customerId) {
        return this.receivableRepo.find({ where: { customer: { id: customerId } }, relations: ['evidences', 'paymentHistory'] });
    }
    async getDebtEvidence(customerId) {
        return this.evidenceRepo.find({ where: { receivable: { customer: { id: customerId } } } });
    }
    async addPayment(customerId, receivableId, dto) {
        const receivable = await this.receivableRepo.findOne({ where: { id: receivableId, customer: { id: customerId } } });
        if (!receivable)
            throw new Error('Receivable not found');
        return this.paymentRepo.save(this.paymentRepo.create({ ...dto, receivable }));
    }
}
exports.CustomerService = CustomerService;
//# sourceMappingURL=customer.service.js.map