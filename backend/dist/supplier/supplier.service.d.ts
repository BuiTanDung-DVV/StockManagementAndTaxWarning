import { Repository } from 'typeorm';
import { Supplier, Payable } from './entities';
export declare class SupplierService {
    private supplierRepo;
    private payableRepo;
    constructor(supplierRepo: Repository<Supplier>, payableRepo: Repository<Payable>);
    findAll(page?: number, limit?: number, search?: string): Promise<{
        items: Supplier[];
        total: number;
        page: number;
        limit: number;
        totalPages: number;
    }>;
    findById(id: number): Promise<Supplier>;
    create(dto: Partial<Supplier>): Promise<Supplier>;
    update(id: number, dto: Partial<Supplier>): Promise<Supplier>;
    findPayables(supplierId: number): Promise<Payable[]>;
}
