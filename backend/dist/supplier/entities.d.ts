export declare class Supplier {
    id: number;
    code: string;
    name: string;
    phone: string;
    email: string;
    address: string;
    taxCode: string;
    balance: number;
    contactPerson: string;
    paymentTermDays: number;
    bankAccount: string;
    bankName: string;
    notes: string;
    isActive: boolean;
    createdAt: Date;
    updatedAt: Date;
}
export declare class Payable {
    id: number;
    supplierId: number;
    purchaseOrderId: number;
    amount: number;
    paidAmount: number;
    dueDate: Date;
    status: string;
    remainingAmount: number;
    notes: string;
    createdAt: Date;
    updatedAt: Date;
}
