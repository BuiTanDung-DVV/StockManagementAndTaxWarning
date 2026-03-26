import { Product } from '../product/entities';
export declare class Warehouse {
    id: number;
    name: string;
    address: string;
    isActive: boolean;
}
export declare class InventoryStock {
    id: number;
    productId: number;
    warehouseId: number;
    quantity: number;
    updatedAt: Date;
}
export declare class InventoryMovement {
    id: number;
    productId: number;
    warehouseId: number;
    movementType: string;
    quantity: number;
    referenceType: string;
    referenceId: number;
    notes: string;
    createdBy: number;
    createdAt: Date;
}
export declare class PurchaseOrder {
    id: number;
    orderCode: string;
    supplierId: number;
    warehouseId: number;
    orderDate: Date;
    paymentDueDate: Date;
    invoiceNumber: string;
    status: string;
    subtotal: number;
    discountAmount: number;
    taxAmount: number;
    totalAmount: number;
    paidAmount: number;
    notes: string;
    createdBy: number;
    items: PurchaseOrderItem[];
    createdAt: Date;
}
export declare class PurchaseOrderItem {
    id: number;
    order: PurchaseOrder;
    product: Product;
    quantity: number;
    unitPrice: number;
    subtotal: number;
}
export declare class StockTake {
    id: number;
    stockTakeCode: string;
    stockTakeDate: Date;
    status: string;
    notes: string;
    items: StockTakeItem[];
    createdBy: number;
    approvedBy: number;
    completedAt: Date;
    createdAt: Date;
}
export declare class StockTakeItem {
    id: number;
    stockTake: StockTake;
    product: Product;
    systemQty: number;
    actualQty: number;
    difference: number;
    notes: string;
}
