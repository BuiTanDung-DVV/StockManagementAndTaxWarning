import { Repository } from 'typeorm';
import { Product, Category, CostType, ProductCostItem, ProductBatch, UnitConversion, ProductPriceHistory } from './entities';
export declare class ProductService {
    private productRepo;
    private categoryRepo;
    private costTypeRepo;
    private costItemRepo;
    private batchRepo;
    private unitRepo;
    private priceHistoryRepo;
    constructor(productRepo: Repository<Product>, categoryRepo: Repository<Category>, costTypeRepo: Repository<CostType>, costItemRepo: Repository<ProductCostItem>, batchRepo: Repository<ProductBatch>, unitRepo: Repository<UnitConversion>, priceHistoryRepo: Repository<ProductPriceHistory>);
    findAllProducts(page?: number, limit?: number, search?: string): Promise<{
        items: Product[];
        total: number;
        page: number;
        limit: number;
        totalPages: number;
    }>;
    findProductById(id: number): Promise<Product>;
    createProduct(dto: Partial<Product>): Promise<Product>;
    updateProduct(id: number, dto: Partial<Product>): Promise<Product>;
    deleteProduct(id: number): Promise<Product>;
    calculateSuggestedPrice(productId: number): Promise<{
        costPrice: number;
        supplierDiscount: number;
        totalAdditionalCost: number;
        taxRate: number;
        profitMargin: number;
        suggestedPrice: number;
        costBreakdown: ProductCostItem[];
    }>;
    findAllCostTypes(): Promise<CostType[]>;
    createCostType(dto: Partial<CostType>): Promise<CostType>;
    addCostItem(productId: number, costTypeId: number, amount: number, calculationType?: string, notes?: string): Promise<ProductCostItem>;
    removeCostItem(id: number): Promise<void>;
    logPriceChange(productId: number, priceType: string, oldPrice: number, newPrice: number, reason?: string, userId?: number): Promise<ProductPriceHistory>;
    getPriceHistory(productId: number): Promise<ProductPriceHistory[]>;
    findBatches(productId: number): Promise<ProductBatch[]>;
    createBatch(productId: number, dto: Partial<ProductBatch>): Promise<ProductBatch>;
    findConversions(productId: number): Promise<UnitConversion[]>;
    createConversion(productId: number, dto: Partial<UnitConversion>): Promise<UnitConversion>;
    findAllCategories(): Promise<Category[]>;
    createCategory(dto: Partial<Category>): Promise<Category>;
}
