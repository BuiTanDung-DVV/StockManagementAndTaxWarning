import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, OneToMany, JoinColumn, CreateDateColumn, UpdateDateColumn } from 'typeorm';

import { Customer } from '../customer/entities';
import { Product } from '../product/entities';

@Entity('sales_orders')
export class SalesOrder {
    @PrimaryGeneratedColumn()
    id: number;

    @Column({ name: 'order_code', unique: true, length: 20 })
    orderCode: string;

    @ManyToOne(() => Customer, { nullable: true })
    @JoinColumn({ name: 'customer_id' })
    customer: Customer;

    @Column({ name: 'order_date' })
    orderDate: Date;

    @Column({ length: 20, default: 'PENDING' })
    status: string; // PENDING, CONFIRMED, DELIVERED, CANCELLED

    @Column({ type: 'decimal', precision: 18, scale: 2, default: 0 })
    subtotal: number;

    @Column({ name: 'discount_amount', type: 'decimal', precision: 18, scale: 2, default: 0 })
    discountAmount: number;

    @Column({ name: 'tax_amount', type: 'decimal', precision: 18, scale: 2, default: 0 })
    taxAmount: number;

    @Column({ name: 'total_amount', type: 'decimal', precision: 18, scale: 2, default: 0 })
    totalAmount: number;

    @Column({ name: 'total_cogs', type: 'decimal', precision: 18, scale: 2, default: 0 })
    totalCogs: number;

    @Column({ name: 'paid_amount', type: 'decimal', precision: 18, scale: 2, default: 0 })
    paidAmount: number;

    @Column({ name: 'payment_method', length: 10, default: 'CASH' })
    paymentMethod: string;

    @Column({ length: 500, nullable: true })
    notes: string;

    @Column({ name: 'return_status', length: 20, default: 'NONE' })
    returnStatus: string; // NONE, PARTIAL_RETURN, FULL_RETURN

    @Column({ name: 'hold_until', nullable: true })
    holdUntil: Date;

    @Column({ name: 'qr_payment_ref', length: 100, nullable: true })
    qrPaymentRef: string;

    @Column({ name: 'invoice_number', length: 50, nullable: true })
    invoiceNumber: string;

    @Column({ name: 'created_by', nullable: true })
    createdBy: number;

    @OneToMany(() => SalesOrderItem, (i) => i.order, { cascade: true })
    items: SalesOrderItem[];

    @OneToMany(() => SalesOrderPayment, (p) => p.order, { cascade: true })
    payments: SalesOrderPayment[];

    @CreateDateColumn({ name: 'created_at' })
    createdAt: Date;

    @UpdateDateColumn({ name: 'updated_at' })
    updatedAt: Date;
}

@Entity('sales_order_items')
export class SalesOrderItem {
    @PrimaryGeneratedColumn()
    id: number;

    @ManyToOne(() => SalesOrder, (o) => o.items)
    @JoinColumn({ name: 'order_id' })
    order: SalesOrder;

    @ManyToOne(() => Product)
    @JoinColumn({ name: 'product_id' })
    product: Product;

    @Column()
    quantity: number;

    @Column({ name: 'unit_price', type: 'decimal', precision: 18, scale: 2 })
    unitPrice: number;

    @Column({ type: 'decimal', precision: 18, scale: 2 })
    subtotal: number;

    @Column({ name: 'cost_price', type: 'decimal', precision: 18, scale: 2, default: 0 })
    costPrice: number;

    @Column({ name: 'tax_rate', type: 'decimal', precision: 5, scale: 2, default: 0 })
    taxRate: number;

    @Column({ name: 'tax_amount', type: 'decimal', precision: 18, scale: 2, default: 0 })
    taxAmount: number;
}

@Entity('sales_order_payments')
export class SalesOrderPayment {
    @PrimaryGeneratedColumn()
    id: number;

    @ManyToOne(() => SalesOrder, (o) => o.payments)
    @JoinColumn({ name: 'order_id' })
    order: SalesOrder;

    @Column({ type: 'decimal', precision: 18, scale: 2 })
    amount: number;

    @Column({ length: 20, default: 'CASH' })
    method: string; // CASH, TRANSFER, MOMO, ZALOPAY, QR

    @Column({ name: 'reference_code', length: 100, nullable: true })
    referenceCode: string;

    @Column({ length: 200, nullable: true })
    notes: string;

    @CreateDateColumn({ name: 'paid_at' })
    paidAt: Date;
}

@Entity('sales_returns')
export class SalesReturn {
    @PrimaryGeneratedColumn()
    id: number;

    @Column({ name: 'return_code', unique: true, length: 20 })
    returnCode: string;

    @ManyToOne(() => SalesOrder)
    @JoinColumn({ name: 'order_id' })
    order: SalesOrder;

    @Column({ name: 'return_date' })
    returnDate: Date;

    @Column({ length: 500 })
    reason: string;

    @Column({ name: 'refund_amount', type: 'decimal', precision: 18, scale: 2, default: 0 })
    refundAmount: number;

    @Column({ name: 'refund_method', length: 20, default: 'CASH' })
    refundMethod: string;

    @Column({ length: 20, default: 'PENDING' })
    status: string;

    @OneToMany(() => SalesReturnItem, (i) => i.salesReturn, { cascade: true })
    items: SalesReturnItem[];

    @Column({ name: 'processed_by', nullable: true })
    processedBy: number;

    @Column({ length: 500, nullable: true })
    notes: string;

    @CreateDateColumn({ name: 'created_at' })
    createdAt: Date;
}

@Entity('sales_return_items')
export class SalesReturnItem {
    @PrimaryGeneratedColumn()
    id: number;

    @ManyToOne(() => SalesReturn, (r) => r.items)
    @JoinColumn({ name: 'return_id' })
    salesReturn: SalesReturn;

    @ManyToOne(() => Product)
    @JoinColumn({ name: 'product_id' })
    product: Product;

    @Column()
    quantity: number;

    @Column({ name: 'unit_price', type: 'decimal', precision: 18, scale: 2 })
    unitPrice: number;

    @Column({ type: 'decimal', precision: 18, scale: 2 })
    subtotal: number;

    @Column({ length: 200, nullable: true })
    reason: string;
}
