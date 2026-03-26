import { SalesService } from './sales.service';
import { ApiResponse } from '../common/response';
export declare class SalesController {
    private svc;
    constructor(svc: SalesService);
    findAll(page?: string, limit?: string, status?: string): Promise<ApiResponse<{
        items: import("./entities").SalesOrder[];
        total: number;
        page: number;
        limit: number;
        totalPages: number;
    }>>;
    summary(from: string, to: string): Promise<ApiResponse<any>>;
    findOne(id: number): Promise<ApiResponse<import("./entities").SalesOrder>>;
    create(dto: any): Promise<ApiResponse<import("./entities").SalesOrder>>;
    cancel(id: number): Promise<ApiResponse<import("./entities").SalesOrder>>;
    addPayment(id: number, dto: any): Promise<ApiResponse<import("./entities").SalesOrderPayment>>;
    createReturn(id: number, dto: any): Promise<ApiResponse<import("./entities").SalesReturn>>;
}
