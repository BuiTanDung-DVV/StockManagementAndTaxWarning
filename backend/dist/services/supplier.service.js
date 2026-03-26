"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.SupplierService = void 0;
const db_config_1 = require("../config/db.config");
const entities_1 = require("../supplier/entities");
class SupplierService {
    constructor() {
        this.supplierRepo = db_config_1.AppDataSource.getRepository(entities_1.Supplier);
        this.payableRepo = db_config_1.AppDataSource.getRepository(entities_1.Payable);
    }
    async findAll(page = 1, limit = 20, search) {
        const qb = this.supplierRepo.createQueryBuilder('s');
        if (search) {
            qb.where('s.name LIKE :s OR s.phone LIKE :s OR s.code LIKE :s', { s: `%${search}%` });
        }
        const [items, total] = await qb.skip((page - 1) * limit).take(limit).orderBy('s.createdAt', 'DESC').getManyAndCount();
        return { items, total, page, limit, totalPages: Math.ceil(total / limit) };
    }
    async findById(id) {
        const supplier = await this.supplierRepo.findOne({ where: { id } });
        if (!supplier)
            throw new Error('Supplier not found');
        return supplier;
    }
    async create(dto) {
        return this.supplierRepo.save(this.supplierRepo.create({ ...dto, code: 'SUP' + Date.now().toString().slice(-6) }));
    }
    async update(id, dto) {
        const supplier = await this.findById(id);
        Object.assign(supplier, dto);
        return this.supplierRepo.save(supplier);
    }
    async remove(id) {
        const supplier = await this.findById(id);
        supplier.isActive = false;
        return this.supplierRepo.save(supplier);
    }
    async getPayables(supplierId) {
        return this.payableRepo.find({ where: { supplierId } });
    }
}
exports.SupplierService = SupplierService;
//# sourceMappingURL=supplier.service.js.map