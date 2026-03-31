import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, OneToMany, JoinColumn, CreateDateColumn } from 'typeorm';

import { Product } from '../product/entities';

@Entity('warehouses')
export class Warehouse {
    @PrimaryGeneratedColumn()
    id: number;

    @Column({ unique: true, length: 100 })
    name: string;

    @Column({ length: 500, nullable: true })
    address: string;

    @Column({ name: 'is_active', default: true })
    isActive: boolean;
}

@Entity('inventory_stocks')
export class InventoryStock {
    @PrimaryGeneratedColumn()
    id: number;

    @Column({ name: 'product_id' })
    productId: number;

    @ManyToOne(() => Product)
    @JoinColumn({ name: 'product_id' })
    product: Product;

    @Column({ name: 'warehouse_id' })
    warehouseId: number;

    @ManyToOne(() => Warehouse)
    @JoinColumn({ name: 'warehouse_id' })
    warehouse: Warehouse;

    @Column({ default: 0 })
    quantity: number;

    @Column({ name: 'updated_at' })
    updatedAt: Date;
}

@Entity('inventory_movements')
export class InventoryMovement {
    @PrimaryGeneratedColumn()
    id: number;

    @Column({ name: 'product_id' })
    productId: number;

    @Column({ name: 'warehouse_id' })
    warehouseId: number;

    @Column({ name: 'movement_type', length: 20 })
    movementType: string; // IN, OUT, ADJUSTMENT, RETURN

    @Column()
    quantity: number;

    @Column({ name: 'reference_type', length: 20, nullable: true })
    referenceType: string;

    @Column({ name: 'reference_id', nullable: true })
    referenceId: number;

    @Column({ length: 500, nullable: true })
    notes: string;

    @Column({ name: 'created_by', nullable: true })
    createdBy: number;

    @CreateDateColumn({ name: 'created_at' })
    createdAt: Date;
}

@Entity('purchase_orders')
export class PurchaseOrder {
    @PrimaryGeneratedColumn()
    id: number;

    @Column({ name: 'order_code', unique: true, length: 20 })
    orderCode: string;

    @Column({ name: 'supplier_id' })
    supplierId: number;

    @Column({ name: 'warehouse_id', nullable: true })
    warehouseId: number;

    @Column({ name: 'order_date' })
    orderDate: Date;

    @Column({ name: 'payment_due_date', type: 'date', nullable: true })
    paymentDueDate: Date;

    @Column({ name: 'invoice_number', length: 50, nullable: true })
    invoiceNumber: string;

    @Column({ length: 20, default: 'PENDING' })
    status: string;

    @Column({ type: 'decimal', precision: 18, scale: 2, default: 0 })
    subtotal: number;

    @Column({ name: 'discount_amount', type: 'decimal', precision: 18, scale: 2, default: 0 })
    discountAmount: number;

    @Column({ name: 'tax_amount', type: 'decimal', precision: 18, scale: 2, default: 0 })
    taxAmount: number;

    @Column({ name: 'total_amount', type: 'decimal', precision: 18, scale: 2, default: 0 })
    totalAmount: number;

    @Column({ name: 'paid_amount', type: 'decimal', precision: 18, scale: 2, default: 0 })
    paidAmount: number;

    @Column({ length: 500, nullable: true })
    notes: string;

    @Column({ name: 'created_by', nullable: true })
    createdBy: number;

    @OneToMany(() => PurchaseOrderItem, (i) => i.order, { cascade: true })
    items: PurchaseOrderItem[];

    @CreateDateColumn({ name: 'created_at' })
    createdAt: Date;
}

@Entity('purchase_order_items')
export class PurchaseOrderItem {
    @PrimaryGeneratedColumn()
    id: number;

    @ManyToOne(() => PurchaseOrder, (o) => o.items)
    @JoinColumn({ name: 'order_id' })
    order: PurchaseOrder;

    @ManyToOne(() => Product)
    @JoinColumn({ name: 'product_id' })
    product: Product;

    @Column()
    quantity: number;

    @Column({ name: 'unit_price', type: 'decimal', precision: 18, scale: 2 })
    unitPrice: number;

    @Column({ type: 'decimal', precision: 18, scale: 2 })
    subtotal: number;
}

@Entity('stock_takes')
export class StockTake {
    @PrimaryGeneratedColumn()
    id: number;

    @Column({ name: 'stock_take_code', unique: true, length: 20 })
    stockTakeCode: string;

    @Column({ name: 'stock_take_date', type: 'date' })
    stockTakeDate: Date;

    @Column({ length: 20, default: 'DRAFT' })
    status: string;

    @Column({ length: 500, nullable: true })
    notes: string;

    @OneToMany(() => StockTakeItem, (i) => i.stockTake, { cascade: true })
    items: StockTakeItem[];

    @Column({ name: 'created_by', nullable: true })
    createdBy: number;

    @Column({ name: 'approved_by', nullable: true })
    approvedBy: number;

    @Column({ name: 'completed_at', nullable: true })
    completedAt: Date;

    @CreateDateColumn({ name: 'created_at' })
    createdAt: Date;
}

@Entity('stock_take_items')
export class StockTakeItem {
    @PrimaryGeneratedColumn()
    id: number;

    @ManyToOne(() => StockTake, (s) => s.items)
    @JoinColumn({ name: 'stock_take_id' })
    stockTake: StockTake;

    @ManyToOne(() => Product)
    @JoinColumn({ name: 'product_id' })
    product: Product;

    @Column({ name: 'system_qty' })
    systemQty: number;

    @Column({ name: 'actual_qty' })
    actualQty: number;

    @Column({ default: 0 })
    difference: number;

    @Column({ length: 200, nullable: true })
    notes: string;
}
