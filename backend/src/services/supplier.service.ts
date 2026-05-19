import { AppDataSource } from '../config/db.config';
import { Supplier, Payable } from '../supplier/entities';

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
