import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, ManyToOne, JoinColumn } from 'typeorm';
import { Product } from '../product/entities';

@Entity('inventory_lots')
export class InventoryLot {
    @PrimaryGeneratedColumn()
    id: number;

    @ManyToOne(() => Product)
    @JoinColumn({ name: 'product_id' })
    product: Product;

    @Column({ name: 'product_id' })
    productId: number;

    @Column({ name: 'purchase_id', nullable: true })
    purchaseId: number;

    @Column({ name: 'batch_id', nullable: true })
    batchId: number;

    @Column({ name: 'lot_date' })
    lotDate: Date;

    @Column({ name: 'initial_qty' })
    initialQty: number;

    @Column({ name: 'remaining_qty' })
    remainingQty: number;

    @Column({ name: 'cost_price', type: 'decimal', precision: 18, scale: 2 })
    costPrice: number;

    @Column({ length: 200, nullable: true })
    notes: string;

    @CreateDateColumn({ name: 'created_at' })
    createdAt: Date;
}
