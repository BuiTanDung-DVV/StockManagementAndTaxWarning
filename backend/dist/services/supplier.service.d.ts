import { Supplier, Payable } from '../supplier/entities';
export declare class SupplierService {
    private supplierRepo;
    private payableRepo;
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
    remove(id: number): Promise<Supplier>;
    getPayables(supplierId: number): Promise<Payable[]>;
}
