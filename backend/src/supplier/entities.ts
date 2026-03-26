import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, UpdateDateColumn } from 'typeorm';

@Entity('suppliers')
export class Supplier {
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

    @Column({ type: 'decimal', precision: 18, scale: 2, default: 0 })
    balance: number;

    @Column({ name: 'contact_person', length: 200, nullable: true })
    contactPerson: string;

    @Column({ name: 'payment_term_days', default: 0 })
    paymentTermDays: number;

    @Column({ name: 'bank_account', length: 30, nullable: true })
    bankAccount: string;

    @Column({ name: 'bank_name', length: 100, nullable: true })
    bankName: string;

    @Column({ length: 500, nullable: true })
    notes: string;

    @Column({ name: 'is_active', default: true })
    isActive: boolean;

    @CreateDateColumn({ name: 'created_at' })
    createdAt: Date;

    @UpdateDateColumn({ name: 'updated_at' })
    updatedAt: Date;
}

@Entity('payables')
export class Payable {
    @PrimaryGeneratedColumn()
    id: number;

    @Column({ name: 'supplier_id' })
    supplierId: number;

    @Column({ name: 'purchase_order_id', nullable: true })
    purchaseOrderId: number;

    @Column({ type: 'decimal', precision: 18, scale: 2 })
    amount: number;

    @Column({ name: 'paid_amount', type: 'decimal', precision: 18, scale: 2, default: 0 })
    paidAmount: number;

    @Column({ name: 'due_date', type: 'date' })
    dueDate: Date;

    @Column({ length: 20, default: 'UNPAID' })
    status: string;

    @Column({ name: 'remaining_amount', type: 'decimal', precision: 18, scale: 2, nullable: true, insert: false, update: false })
    remainingAmount: number;

    @Column({ length: 500, nullable: true })
    notes: string;

    @CreateDateColumn({ name: 'created_at' })
    createdAt: Date;

    @UpdateDateColumn({ name: 'updated_at' })
    updatedAt: Date;
}
