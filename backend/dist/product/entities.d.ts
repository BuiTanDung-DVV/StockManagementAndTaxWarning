export declare class Category {
    id: number;
    name: string;
    description: string;
    isActive: boolean;
    products: Product[];
}
export declare class Product {
    id: number;
    sku: string;
    name: string;
    category: Category;
    unit: string;
    costPrice: number;
    sellingPrice: number;
    wholesalePrice: number;
    wholesaleMinQty: number;
    taxRate: number;
    profitMargin: number;
    supplierDiscount: number;
    promoPrice: number;
    promoStart: Date;
    promoEnd: Date;
    totalAdditionalCost: number;
    suggestedPrice: number;
    minStock: number;
    imageUrl: string;
    barcode: string;
    description: string;
    isActive: boolean;
    costItems: ProductCostItem[];
    createdAt: Date;
    updatedAt: Date;
}
export declare class CostType {
    id: number;
    name: string;
    description: string;
    isActive: boolean;
    sortOrder: number;
    createdAt: Date;
}
export declare class ProductCostItem {
    id: number;
    product: Product;
    costType: CostType;
    amount: number;
    calculationType: string;
    notes: string;
}
export declare class ProductBatch {
    id: number;
    product: Product;
    batchNumber: string;
    manufacturingDate: Date;
    expiryDate: Date;
    quantity: number;
    costPrice: number;
    supplierName: string;
    notes: string;
    isActive: boolean;
    createdAt: Date;
}
export declare class UnitConversion {
    id: number;
    product: Product;
    fromUnit: string;
    toUnit: string;
    conversionRate: number;
    sellingPricePerUnit: number;
}
export declare class ProductPriceHistory {
    id: number;
    product: Product;
    priceType: string;
    oldPrice: number;
    newPrice: number;
    changeReason: string;
    changedBy: number;
    changedAt: Date;
}
