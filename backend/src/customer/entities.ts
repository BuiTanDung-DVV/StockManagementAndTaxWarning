import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, OneToMany, JoinColumn, CreateDateColumn, UpdateDateColumn } from 'typeorm';


@Entity('customers')
export class Customer {
    @PrimaryGeneratedColumn()
    id: number;

    @Column({ unique: true, length: 20 })
    code: string;

    @Column({ length: 200 })
    name: string;

    @Column({ length: 20, nullable: true })
    phone: string;

    @Column({ length: 100, nullable: true })
    email: string;

    @Column({ length: 500, nullable: true })
    address: string;

    @Column({ name: 'tax_code', length: 20, nullable: true })
    taxCode: string;

    // Identity verification
    @Column({ name: 'identity_number', length: 20, nullable: true })
    identityNumber: string;

    @Column({ name: 'identity_image_url', length: 1000, nullable: true })
    identityImageUrl: string;

    @Column({ name: 'avatar_url', length: 1000, nullable: true })
    avatarUrl: string;

    @Column({ name: 'date_of_birth', type: 'date', nullable: true })
    dateOfBirth: Date;

    @Column({ name: 'customer_type', length: 20, default: 'RETAIL' })
    customerType: string; // RETAIL, WHOLESALE, VIP

    @Column({ name: 'zalo_phone', length: 20, nullable: true })
    zaloPhone: string;

    @Column({ name: 'credit_limit', type: 'decimal', precision: 18, scale: 2, default: 0 })
    creditLimit: number;

    @Column({ type: 'decimal', precision: 18, scale: 2, default: 0 })
    balance: number;

    @Column({ length: 500, nullable: true })
    notes: string;

    @Column({ name: 'is_active', default: true })
    isActive: boolean;

    @OneToMany(() => Receivable, (r) => r.customer)
    receivables: Receivable[];

    @CreateDateColumn({ name: 'created_at' })
    createdAt: Date;

    @UpdateDateColumn({ name: 'updated_at' })
    updatedAt: Date;
}

@Entity('receivables')
export class Receivable {
    @PrimaryGeneratedColumn()
    id: number;

    @ManyToOne(() => Customer, (c) => c.receivables)
    @JoinColumn({ name: 'customer_id' })
    customer: Customer;

    @Column({ name: 'order_id', nullable: true })
    orderId: number;

    @Column({ type: 'decimal', precision: 18, scale: 2 })
    amount: number;

    @Column({ name: 'paid_amount', type: 'decimal', precision: 18, scale: 2, default: 0 })
    paidAmount: number;

    @Column({ name: 'due_date', type: 'date' })
    dueDate: Date;

    @Column({ length: 20, default: 'UNPAID' })
    status: string; // UNPAID, PARTIAL, PAID, OVERDUE

    @Column({ name: 'remaining_amount', type: 'decimal', precision: 18, scale: 2, nullable: true, insert: false, update: false })
    remainingAmount: number;

    @Column({ length: 500, nullable: true })
    notes: string;

    @Column({ name: 'debt_reason', length: 500, nullable: true })
    debtReason: string;

    @Column({ name: 'witness_name', length: 200, nullable: true })
    witnessName: string;

    @Column({ name: 'reminder_enabled', default: false })
    reminderEnabled: boolean;

    @Column({ name: 'last_reminder_at', nullable: true })
    lastReminderAt: Date;

    @OneToMany(() => DebtEvidence, (e) => e.receivable, { cascade: true })
    evidences: DebtEvidence[];

    @OneToMany(() => DebtPaymentHistory, (p) => p.receivable, { cascade: true })
    paymentHistory: DebtPaymentHistory[];

    @CreateDateColumn({ name: 'created_at' })
    createdAt: Date;

    @UpdateDateColumn({ name: 'updated_at' })
    updatedAt: Date;
}

@Entity('debt_evidences')
export class DebtEvidence {
    @PrimaryGeneratedColumn()
    id: number;

    @ManyToOne(() => Receivable, (r) => r.evidences, { nullable: true })
    @JoinColumn({ name: 'receivable_id' })
    receivable: Receivable;

    @Column({ name: 'payable_id', nullable: true })
    payableId: number;

    @Column({ length: 20 })
    type: string; // PHOTO, SIGNATURE, AUDIO, DOCUMENT, CONTRACT

    @Column({ name: 'file_url', length: 1000 })
    fileUrl: string;

    @Column({ name: 'file_name', length: 200, nullable: true })
    fileName: string;

    @Column({ name: 'file_size', type: 'bigint', nullable: true })
    fileSize: number;

    @Column({ length: 500, nullable: true })
    description: string;

    @Column({ name: 'uploaded_by', nullable: true })
    uploadedBy: number;

    @CreateDateColumn({ name: 'uploaded_at' })
    uploadedAt: Date;
}

@Entity('debt_payment_history')
export class DebtPaymentHistory {
    @PrimaryGeneratedColumn()
    id: number;

    @ManyToOne(() => Receivable, (r) => r.paymentHistory, { nullable: true })
    @JoinColumn({ name: 'receivable_id' })
    receivable: Receivable;

    @Column({ name: 'payable_id', nullable: true })
    payableId: number;

    @Column({ type: 'decimal', precision: 18, scale: 2 })
    amount: number;

    @Column({ name: 'payment_method', length: 20, default: 'CASH' })
    paymentMethod: string;

    @Column({ name: 'payment_date' })
    paymentDate: Date;

    @Column({ name: 'evidence_url', length: 1000, nullable: true })
    evidenceUrl: string;

    @Column({ length: 500, nullable: true })
    notes: string;

    @Column({ name: 'recorded_by', nullable: true })
    recordedBy: number;

    @CreateDateColumn({ name: 'created_at' })
    createdAt: Date;
}
