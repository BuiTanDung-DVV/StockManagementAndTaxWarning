import { SupplierService } from './supplier.service';
import { ApiResponse } from '../common/response';
export declare class SupplierController {
    private svc;
    constructor(svc: SupplierService);
    findAll(page?: string, limit?: string, search?: string): Promise<ApiResponse<{
        items: import("./entities").Supplier[];
        total: number;
        page: number;
        limit: number;
        totalPages: number;
    }>>;
    findOne(id: number): Promise<ApiResponse<import("./entities").Supplier>>;
    create(dto: any): Promise<ApiResponse<import("./entities").Supplier>>;
    update(id: number, dto: any): Promise<ApiResponse<import("./entities").Supplier>>;
    payables(id: number): Promise<ApiResponse<import("./entities").Payable[]>>;
}
