import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, OneToMany, JoinColumn, CreateDateColumn, UpdateDateColumn } from 'typeorm';

@Entity('categories')
export class Category {
    @PrimaryGeneratedColumn()
    id: number;

    @Column({ unique: true, length: 100 })
    name: string;

    @Column({ length: 500, nullable: true })
    description: string;

    @Column({ name: 'is_active', default: true })
    isActive: boolean;

    @OneToMany(() => Product, (p) => p.category)
    products: Product[];
}

@Entity('products')
export class Product {
    @PrimaryGeneratedColumn()
    id: number;

    @Column({ unique: true, length: 50 })
    sku: string;

    @Column({ length: 200 })
    name: string;

    @ManyToOne(() => Category, { nullable: true })
    @JoinColumn({ name: 'category_id' })
    category: Category;

    @Column({ length: 20, default: 'Cái' })
    unit: string;

    // === PRICING ===
    @Column({ name: 'cost_price', type: 'decimal', precision: 18, scale: 2, default: 0 })
    costPrice: number;

    @Column({ name: 'selling_price', type: 'decimal', precision: 18, scale: 2, default: 0 })
    sellingPrice: number;

    @Column({ name: 'wholesale_price', type: 'decimal', precision: 18, scale: 2, nullable: true })
    wholesalePrice: number;

    @Column({ name: 'wholesale_min_qty', nullable: true })
    wholesaleMinQty: number;

    @Column({ name: 'tax_rate', type: 'decimal', precision: 5, scale: 2, default: 0 })
    taxRate: number;

    @Column({ name: 'profit_margin', type: 'decimal', precision: 5, scale: 2, nullable: true })
    profitMargin: number;

    @Column({ name: 'supplier_discount', type: 'decimal', precision: 18, scale: 2, default: 0 })
    supplierDiscount: number;

    @Column({ name: 'promo_price', type: 'decimal', precision: 18, scale: 2, nullable: true })
    promoPrice: number;

    @Column({ name: 'promo_start', type: 'date', nullable: true })
    promoStart: Date;

    @Column({ name: 'promo_end', type: 'date', nullable: true })
    promoEnd: Date;

    @Column({ name: 'total_additional_cost', type: 'decimal', precision: 18, scale: 2, default: 0 })
    totalAdditionalCost: number;

    @Column({ name: 'suggested_price', type: 'decimal', precision: 18, scale: 2, nullable: true })
    suggestedPrice: number;

    // === STOCK ===
    @Column({ name: 'min_stock', default: 0 })
    minStock: number;

    // === META ===
    @Column({ name: 'image_url', length: 500, nullable: true })
    imageUrl: string;

    @Column({ length: 50, nullable: true })
    barcode: string;

    @Column({ length: 1000, nullable: true })
    description: string;

    @Column({ name: 'is_active', default: true })
    isActive: boolean;

    @OneToMany(() => ProductCostItem, (ci) => ci.product, { cascade: true })
    costItems: ProductCostItem[];

    @CreateDateColumn({ name: 'created_at' })
    createdAt: Date;

    @UpdateDateColumn({ name: 'updated_at' })
    updatedAt: Date;
}

@Entity('cost_types')
export class CostType {
    @PrimaryGeneratedColumn()
    id: number;

    @Column({ unique: true, length: 100 })
    name: string;

    @Column({ length: 500, nullable: true })
    description: string;

    @Column({ name: 'is_active', default: true })
    isActive: boolean;

    @Column({ name: 'sort_order', default: 0 })
    sortOrder: number;

    @CreateDateColumn({ name: 'created_at' })
    createdAt: Date;
}

@Entity('product_cost_items')
export class ProductCostItem {
    @PrimaryGeneratedColumn()
    id: number;

    @ManyToOne(() => Product, (p) => p.costItems)
    @JoinColumn({ name: 'product_id' })
    product: Product;

    @ManyToOne(() => CostType)
    @JoinColumn({ name: 'cost_type_id' })
    costType: CostType;

    @Column({ type: 'decimal', precision: 18, scale: 2 })
    amount: number;

    @Column({ name: 'calculation_type', length: 20, default: 'FIXED' })
    calculationType: string; // FIXED | PERCENTAGE

    @Column({ length: 200, nullable: true })
    notes: string;
}

@Entity('product_batches')
export class ProductBatch {
    @PrimaryGeneratedColumn()
    id: number;

    @ManyToOne(() => Product)
    @JoinColumn({ name: 'product_id' })
    product: Product;

    @Column({ name: 'batch_number', length: 50 })
    batchNumber: string;

    @Column({ name: 'manufacturing_date', type: 'date', nullable: true })
    manufacturingDate: Date;

    @Column({ name: 'expiry_date', type: 'date', nullable: true })
    expiryDate: Date;

    @Column({ default: 0 })
    quantity: number;

    @Column({ name: 'cost_price', type: 'decimal', precision: 18, scale: 2, nullable: true })
    costPrice: number;

    @Column({ name: 'supplier_name', length: 200, nullable: true })
    supplierName: string;

    @Column({ length: 500, nullable: true })
    notes: string;

    @Column({ name: 'is_active', default: true })
    isActive: boolean;

    @CreateDateColumn({ name: 'created_at' })
    createdAt: Date;
}

@Entity('unit_conversions')
export class UnitConversion {
    @PrimaryGeneratedColumn()
    id: number;

    @ManyToOne(() => Product)
    @JoinColumn({ name: 'product_id' })
    product: Product;

    @Column({ name: 'from_unit', length: 30 })
    fromUnit: string;

    @Column({ name: 'to_unit', length: 30 })
    toUnit: string;

    @Column({ name: 'conversion_rate', type: 'decimal', precision: 18, scale: 4 })
    conversionRate: number;

    @Column({ name: 'selling_price_per_unit', type: 'decimal', precision: 18, scale: 2, nullable: true })
    sellingPricePerUnit: number;
}

@Entity('product_price_history')
export class ProductPriceHistory {
    @PrimaryGeneratedColumn()
    id: number;

    @ManyToOne(() => Product)
    @JoinColumn({ name: 'product_id' })
    product: Product;

    @Column({ name: 'price_type', length: 30 })
    priceType: string; // COST, SELLING, WHOLESALE, PROMO

    @Column({ name: 'old_price', type: 'decimal', precision: 18, scale: 2 })
    oldPrice: number;

    @Column({ name: 'new_price', type: 'decimal', precision: 18, scale: 2 })
    newPrice: number;

    @Column({ name: 'change_reason', length: 500, nullable: true })
    changeReason: string;

    @Column({ name: 'changed_by', nullable: true })
    changedBy: number;

    @CreateDateColumn({ name: 'changed_at' })
    changedAt: Date;
}
