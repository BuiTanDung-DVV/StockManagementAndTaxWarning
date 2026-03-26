import { Customer } from '../customer/entities';
import { Product } from '../product/entities';
export declare class SalesOrder {
    id: number;
    orderCode: string;
    customer: Customer;
    orderDate: Date;
    status: string;
    subtotal: number;
    discountAmount: number;
    taxAmount: number;
    totalAmount: number;
    paidAmount: number;
    paymentMethod: string;
    notes: string;
    returnStatus: string;
    holdUntil: Date;
    qrPaymentRef: string;
    invoiceNumber: string;
    createdBy: number;
    items: SalesOrderItem[];
    payments: SalesOrderPayment[];
    createdAt: Date;
    updatedAt: Date;
}
export declare class SalesOrderItem {
    id: number;
    order: SalesOrder;
    product: Product;
    quantity: number;
    unitPrice: number;
    subtotal: number;
    taxRate: number;
    taxAmount: number;
}
export declare class SalesOrderPayment {
    id: number;
    order: SalesOrder;
    amount: number;
    method: string;
    referenceCode: string;
    notes: string;
    paidAt: Date;
}
export declare class SalesReturn {
    id: number;
    returnCode: string;
    order: SalesOrder;
    returnDate: Date;
    reason: string;
    refundAmount: number;
    refundMethod: string;
    status: string;
    items: SalesReturnItem[];
    processedBy: number;
    notes: string;
    createdAt: Date;
}
export declare class SalesReturnItem {
    id: number;
    salesReturn: SalesReturn;
    product: Product;
    quantity: number;
    unitPrice: number;
    subtotal: number;
    reason: string;
}
