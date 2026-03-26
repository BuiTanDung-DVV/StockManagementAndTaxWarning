export declare class Customer {
    id: number;
    code: string;
    name: string;
    phone: string;
    email: string;
    address: string;
    taxCode: string;
    identityNumber: string;
    identityImageUrl: string;
    avatarUrl: string;
    dateOfBirth: Date;
    customerType: string;
    zaloPhone: string;
    creditLimit: number;
    balance: number;
    notes: string;
    isActive: boolean;
    receivables: Receivable[];
    createdAt: Date;
    updatedAt: Date;
}
export declare class Receivable {
    id: number;
    customer: Customer;
    orderId: number;
    amount: number;
    paidAmount: number;
    dueDate: Date;
    status: string;
    remainingAmount: number;
    notes: string;
    debtReason: string;
    witnessName: string;
    reminderEnabled: boolean;
    lastReminderAt: Date;
    evidences: DebtEvidence[];
    paymentHistory: DebtPaymentHistory[];
    createdAt: Date;
    updatedAt: Date;
}
export declare class DebtEvidence {
    id: number;
    receivable: Receivable;
    payableId: number;
    type: string;
    fileUrl: string;
    fileName: string;
    fileSize: number;
    description: string;
    uploadedBy: number;
    uploadedAt: Date;
}
export declare class DebtPaymentHistory {
    id: number;
    receivable: Receivable;
    payableId: number;
    amount: number;
    paymentMethod: string;
    paymentDate: Date;
    evidenceUrl: string;
    notes: string;
    recordedBy: number;
    createdAt: Date;
}
