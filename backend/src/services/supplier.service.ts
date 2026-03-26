import { AppDataSource } from '../config/db.config';
import { Supplier, Payable } from '../supplier/entities';

export class SupplierService {
    private supplierRepo = AppDataSource.getRepository(Supplier);
    private payableRepo = AppDataSource.getRepository(Payable);

    async findAll(page = 1, limit = 20, search?: string) {
        const qb = this.supplierRepo.createQueryBuilder('s');
        if (search) {
            qb.where('s.name LIKE :s OR s.phone LIKE :s OR s.code LIKE :s', { s: `%${search}%` });
        }
        const [items, total] = await qb.skip((page - 1) * limit).take(limit).orderBy('s.createdAt', 'DESC').getManyAndCount();
        return { items, total, page, limit, totalPages: Math.ceil(total / limit) };
    }

    async findById(id: number) {
        const supplier = await this.supplierRepo.findOne({ where: { id } });
        if (!supplier) throw new Error('Supplier not found');
        return supplier;
    }

    async create(dto: Partial<Supplier>) {
        return this.supplierRepo.save(this.supplierRepo.create({ ...dto, code: 'SUP' + Date.now().toString().slice(-6) }));
    }

    async update(id: number, dto: Partial<Supplier>) {
        const supplier = await this.findById(id);
        Object.assign(supplier, dto);
        return this.supplierRepo.save(supplier);
    }

    async remove(id: number) {
        const supplier = await this.findById(id);
        supplier.isActive = false;
        return this.supplierRepo.save(supplier);
    }

    async getPayables(supplierId: number) {
        return this.payableRepo.find({ where: { supplierId } });
    }
}
