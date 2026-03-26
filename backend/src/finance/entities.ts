import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn, CreateDateColumn } from 'typeorm';


@Entity('cash_accounts')
export class CashAccount {
    @PrimaryGeneratedColumn()
    id: number;

    @Column({ length: 100 })
    name: string;

    @Column({ name: 'account_type', length: 20 })
    accountType: string;

    @Column({ type: 'decimal', precision: 18, scale: 2, default: 0 })
    balance: number;

    @Column({ name: 'is_active', default: true })
    isActive: boolean;
}

@Entity('cash_transactions')
export class CashTransaction {
    @PrimaryGeneratedColumn()
    id: number;

    @Column({ name: 'transaction_code', unique: true, length: 20 })
    transactionCode: string;

    @Column({ length: 10 })
    type: string; // INCOME, EXPENSE

    @Column({ length: 50 })
    category: string; // SALES, PURCHASE, SALARY, RENT, UTILITIES, OTHER

    @Column({ type: 'decimal', precision: 18, scale: 2 })
    amount: number;

    @Column({ name: 'payment_method', length: 10, default: 'CASH' })
    paymentMethod: string;

    @ManyToOne(() => CashAccount, { nullable: true })
    @JoinColumn({ name: 'account_id' })
    account: CashAccount;

    @Column({ length: 200, nullable: true })
    counterparty: string;

    @Column({ name: 'reference_type', length: 20, nullable: true })
    referenceType: string;

    @Column({ name: 'reference_id', nullable: true })
    referenceId: number;

    @Column({ name: 'transaction_date', type: 'date' })
    transactionDate: Date;

    @Column({ length: 500, nullable: true })
    notes: string;

    @Column({ name: 'receipt_image_url', length: 1000, nullable: true })
    receiptImageUrl: string;

    @Column({ name: 'running_balance', type: 'decimal', precision: 18, scale: 2, nullable: true })
    runningBalance: number;

    @Column({ name: 'approved_by', nullable: true })
    approvedBy: number;

    @Column({ name: 'created_by', nullable: true })
    createdBy: number;

    @CreateDateColumn({ name: 'created_at' })
    createdAt: Date;
}

@Entity('budget_plans')
export class BudgetPlan {
    @PrimaryGeneratedColumn()
    id: number;

    @Column({ length: 200 })
    name: string;

    @Column({ length: 20 })
    period: string;

    @Column({ name: 'start_date', type: 'date' })
    startDate: Date;

    @Column({ name: 'end_date', type: 'date' })
    endDate: Date;

    @Column({ name: 'planned_income', type: 'decimal', precision: 18, scale: 2, default: 0 })
    plannedIncome: number;

    @Column({ name: 'planned_expense', type: 'decimal', precision: 18, scale: 2, default: 0 })
    plannedExpense: number;

    @Column({ name: 'actual_income', type: 'decimal', precision: 18, scale: 2, default: 0 })
    actualIncome: number;

    @Column({ name: 'actual_expense', type: 'decimal', precision: 18, scale: 2, default: 0 })
    actualExpense: number;

    @Column({ length: 500, nullable: true })
    notes: string;

    @CreateDateColumn({ name: 'created_at' })
    createdAt: Date;
}

@Entity('cashflow_forecasts')
export class CashflowForecast {
    @PrimaryGeneratedColumn()
    id: number;

    @Column({ name: 'forecast_date', type: 'date' })
    forecastDate: Date;

    @Column({ name: 'expected_income', type: 'decimal', precision: 18, scale: 2, default: 0 })
    expectedIncome: number;

    @Column({ name: 'expected_expense', type: 'decimal', precision: 18, scale: 2, default: 0 })
    expectedExpense: number;

    @Column({ name: 'expected_balance', type: 'decimal', precision: 18, scale: 2, default: 0 })
    expectedBalance: number;

    @Column({ length: 500, nullable: true })
    notes: string;

    @CreateDateColumn({ name: 'created_at' })
    createdAt: Date;
}

@Entity('daily_closings')
export class DailyClosing {
    @PrimaryGeneratedColumn()
    id: number;

    @Column({ name: 'closing_date', type: 'date', unique: true })
    closingDate: Date;

    @Column({ name: 'opening_cash', type: 'decimal', precision: 18, scale: 2, default: 0 })
    openingCash: number;

    @Column({ name: 'closing_cash', type: 'decimal', precision: 18, scale: 2, default: 0 })
    closingCash: number;

    @Column({ name: 'expected_cash', type: 'decimal', precision: 18, scale: 2, default: 0 })
    expectedCash: number;

    @Column({ name: 'cash_difference', type: 'decimal', precision: 18, scale: 2, default: 0 })
    cashDifference: number;

    @Column({ name: 'total_sales', type: 'decimal', precision: 18, scale: 2, default: 0 })
    totalSales: number;

    @Column({ name: 'total_returns', type: 'decimal', precision: 18, scale: 2, default: 0 })
    totalReturns: number;

    @Column({ name: 'total_income', type: 'decimal', precision: 18, scale: 2, default: 0 })
    totalIncome: number;

    @Column({ name: 'total_expense', type: 'decimal', precision: 18, scale: 2, default: 0 })
    totalExpense: number;

    @Column({ name: 'order_count', default: 0 })
    orderCount: number;

    @Column({ length: 500, nullable: true })
    notes: string;

    @Column({ name: 'closed_by', nullable: true })
    closedBy: number;

    @Column({ name: 'closed_at' })
    closedAt: Date;
}

@Entity('invoices')
export class Invoice {
    @PrimaryGeneratedColumn()
    id: number;

    @Column({ name: 'invoice_number', length: 50 })
    invoiceNumber: string;

    @Column({ name: 'invoice_symbol', length: 20, nullable: true })
    invoiceSymbol: string;

    @Column({ name: 'invoice_type', length: 10 })
    invoiceType: string; // IN, OUT

    @Column({ name: 'invoice_date', type: 'date' })
    invoiceDate: Date;

    @Column({ name: 'partner_name', length: 200 })
    partnerName: string;

    @Column({ name: 'partner_tax_code', length: 20, nullable: true })
    partnerTaxCode: string;

    @Column({ name: 'partner_address', length: 500, nullable: true })
    partnerAddress: string;

    @Column({ name: 'partner_identity_number', length: 20, nullable: true })
    partnerIdentityNumber: string;

    @Column({ name: 'reference_type', length: 30, nullable: true })
    referenceType: string;

    @Column({ name: 'reference_id', nullable: true })
    referenceId: number;

    @Column({ type: 'decimal', precision: 18, scale: 2, default: 0 })
    subtotal: number;

    @Column({ name: 'tax_amount', type: 'decimal', precision: 18, scale: 2, default: 0 })
    taxAmount: number;

    @Column({ name: 'total_amount', type: 'decimal', precision: 18, scale: 2, default: 0 })
    totalAmount: number;

    @Column({ name: 'payment_method', length: 20, nullable: true })
    paymentMethod: string;

    @Column({ name: 'payment_status', length: 20, default: 'UNPAID' })
    paymentStatus: string; // PAID, UNPAID, PARTIAL

    @Column({ name: 'image_url', length: 1000, nullable: true })
    imageUrl: string;

    @Column({ length: 500, nullable: true })
    notes: string;

    @Column({ name: 'created_by', nullable: true })
    createdBy: number;

    @CreateDateColumn({ name: 'created_at' })
    createdAt: Date;
}

@Entity('tax_obligations')
export class TaxObligation {
    @PrimaryGeneratedColumn()
    id: number;

    @Column({ length: 20 })
    period: string; // e.g. 'Q1/2026'

    @Column({ name: 'vat_declared', type: 'decimal', precision: 18, scale: 2, default: 0 })
    vatDeclared: number;

    @Column({ name: 'pit_declared', type: 'decimal', precision: 18, scale: 2, default: 0 })
    pitDeclared: number;

    @Column({ name: 'vat_paid', type: 'decimal', precision: 18, scale: 2, default: 0 })
    vatPaid: number;

    @Column({ name: 'pit_paid', type: 'decimal', precision: 18, scale: 2, default: 0 })
    pitPaid: number;

    @Column({ name: 'due_date', type: 'date', nullable: true })
    dueDate: Date;

    @Column({ length: 20, default: 'pending' })
    status: string; // done, partial, pending, overdue

    @CreateDateColumn({ name: 'created_at' })
    createdAt: Date;
}

@Entity('purchases_without_invoice')
export class PurchaseWithoutInvoice {
    @PrimaryGeneratedColumn()
    id: number;

    @Column({ name: 'record_code', length: 20, unique: true })
    recordCode: string;

    @Column({ name: 'purchase_date', type: 'date' })
    purchaseDate: Date;

    @Column({ name: 'seller_name', length: 200 })
    sellerName: string;

    @Column({ name: 'seller_identity_number', length: 20 })
    sellerIdentityNumber: string;

    @Column({ name: 'seller_address', length: 500, nullable: true })
    sellerAddress: string;

    @Column({ name: 'seller_phone', length: 20, nullable: true })
    sellerPhone: string;

    @Column({ name: 'seller_signature_url', length: 1000, nullable: true })
    sellerSignatureUrl: string;

    @Column({ name: 'total_amount', type: 'decimal', precision: 18, scale: 2 })
    totalAmount: number;

    @Column({ name: 'payment_method', length: 20, default: 'CASH' })
    paymentMethod: string;

    @Column({ name: 'payment_proof_url', length: 1000, nullable: true })
    paymentProofUrl: string;

    @Column({ name: 'market_price_reference', type: 'decimal', precision: 18, scale: 2, nullable: true })
    marketPriceReference: number;

    @Column({ length: 500, nullable: true })
    notes: string;

    @Column({ name: 'approved_by', nullable: true })
    approvedBy: number;

    @Column({ name: 'created_by', nullable: true })
    createdBy: number;

    @CreateDateColumn({ name: 'created_at' })
    createdAt: Date;
}
