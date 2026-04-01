import { Product } from '../product/entities';
export declare class ShopProfile {
    id: number;
    shopName: string;
    logoUrl: string;
    phone: string;
    address: string;
    taxCode: string;
    bankAccount: string;
    bankId: string;
    bankName: string;
    accountHolder: string;
    qrPaymentUrl: string;
    receiptFooter: string;
    email: string;
    website: string;
    ownerName: string;
    ownerIdentityNumber: string;
    businessLicenseNumber: string;
    costingMethod: string;
}
export declare class ActivityLog {
    id: number;
    userId: number;
    action: string;
    entityType: string;
    entityId: number;
    entityName: string;
    oldValue: string;
    newValue: string;
    description: string;
    ipAddress: string;
    createdAt: Date;
}
export declare class InvoiceScan {
    id: number;
    scanCode: string;
    imageUrl: string;
    imageThumbnailUrl: string;
    invoiceType: string;
    status: string;
    ocrRawText: string;
    ocrParsedData: string;
    confirmedData: string;
    confidenceScore: number;
    totalAmount: number;
    referenceType: string;
    referenceId: number;
    ocrEngine: string;
    scannedBy: number;
    scannedAt: Date;
    confirmedAt: Date;
    notes: string;
}
export declare class Invoice {
    id: number;
    invoiceNumber: string;
    invoiceSymbol: string;
    invoiceType: string;
    invoiceDate: Date;
    partnerName: string;
    partnerTaxCode: string;
    partnerAddress: string;
    partnerIdentityNumber: string;
    referenceType: string;
    referenceId: number;
    subtotal: number;
    taxAmount: number;
    totalAmount: number;
    paymentMethod: string;
    paymentStatus: string;
    imageUrl: string;
    notes: string;
    items: InvoiceItem[];
    createdBy: number;
    createdAt: Date;
}
export declare class InvoiceItem {
    id: number;
    invoice: Invoice;
    product: Product;
    itemName: string;
    unit: string;
    quantity: number;
    unitPrice: number;
    subtotal: number;
    taxRate: number;
    taxAmount: number;
}
export declare class PurchaseWithoutInvoice {
    id: number;
    recordCode: string;
    purchaseDate: Date;
    sellerName: string;
    sellerIdentityNumber: string;
    sellerAddress: string;
    sellerPhone: string;
    sellerSignatureUrl: string;
    totalAmount: number;
    paymentMethod: string;
    paymentProofUrl: string;
    marketPriceReference: number;
    notes: string;
    items: PurchaseWithoutInvoiceItem[];
    approvedBy: number;
    createdBy: number;
    createdAt: Date;
}
export declare class PurchaseWithoutInvoiceItem {
    id: number;
    purchase: PurchaseWithoutInvoice;
    itemName: string;
    unit: string;
    quantity: number;
    unitPrice: number;
    subtotal: number;
}
