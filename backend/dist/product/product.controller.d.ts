import { ProductService } from './product.service';
import { ApiResponse } from '../common/response';
export declare class ProductController {
    private svc;
    constructor(svc: ProductService);
    findAll(page?: string, limit?: string, search?: string): Promise<ApiResponse<{
        items: import("./entities").Product[];
        total: number;
        page: number;
        limit: number;
        totalPages: number;
    }>>;
    findOne(id: number): Promise<ApiResponse<import("./entities").Product>>;
    create(dto: any): Promise<ApiResponse<import("./entities").Product>>;
    update(id: number, dto: any): Promise<ApiResponse<import("./entities").Product>>;
    remove(id: number): Promise<ApiResponse<import("./entities").Product>>;
    calculatePrice(id: number): Promise<ApiResponse<{
        costPrice: number;
        supplierDiscount: number;
        totalAdditionalCost: number;
        taxRate: number;
        profitMargin: number;
        suggestedPrice: number;
        costBreakdown: import("./entities").ProductCostItem[];
    }>>;
    addCostItem(id: number, dto: {
        costTypeId: number;
        amount: number;
        calculationType?: string;
        notes?: string;
    }): Promise<ApiResponse<import("./entities").ProductCostItem>>;
    removeCostItem(itemId: number): Promise<ApiResponse<null>>;
    priceHistory(id: number): Promise<ApiResponse<import("./entities").ProductPriceHistory[]>>;
    batches(id: number): Promise<ApiResponse<import("./entities").ProductBatch[]>>;
    createBatch(id: number, dto: any): Promise<ApiResponse<import("./entities").ProductBatch>>;
    conversions(id: number): Promise<ApiResponse<import("./entities").UnitConversion[]>>;
    createConversion(id: number, dto: any): Promise<ApiResponse<import("./entities").UnitConversion>>;
}
export declare class CategoryController {
    private svc;
    constructor(svc: ProductService);
    findAll(): Promise<ApiResponse<import("./entities").Category[]>>;
    create(dto: any): Promise<ApiResponse<import("./entities").Category>>;
}
export declare class CostTypeController {
    private svc;
    constructor(svc: ProductService);
    findAll(): Promise<ApiResponse<import("./entities").CostType[]>>;
    create(dto: any): Promise<ApiResponse<import("./entities").CostType>>;
}
