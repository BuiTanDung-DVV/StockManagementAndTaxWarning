import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, OneToMany, JoinColumn, CreateDateColumn } from 'typeorm';
import { Product } from '../product/entities';


@Entity('shop_profiles')
export class ShopProfile {
    @PrimaryGeneratedColumn()
    id: number;

    @Column({ name: 'shop_name', length: 200 })
    shopName: string;

    @Column({ name: 'shop_id', nullable: true })
    shopId: number;

    @Column({ name: 'shop_code', length: 20, unique: true, nullable: true })
    shopCode: string;

    @Column({ name: 'logo_url', length: 1000, nullable: true })
    logoUrl: string;

    @Column({ length: 20, nullable: true })
    phone: string;

    @Column({ length: 500, nullable: true })
    address: string;

    @Column({ name: 'tax_code', length: 20, nullable: true })
    taxCode: string;

    @Column({ name: 'bank_account', length: 30, nullable: true })
    bankAccount: string;

    @Column({ name: 'bank_id', length: 20, nullable: true })
    bankId: string;

    @Column({ name: 'bank_name', length: 100, nullable: true })
    bankName: string;

    @Column({ name: 'account_holder', length: 200, nullable: true })
    accountHolder: string;

    @Column({ name: 'qr_payment_url', length: 1000, nullable: true })
    qrPaymentUrl: string;

    @Column({ name: 'receipt_footer', length: 500, nullable: true })
    receiptFooter: string;

    @Column({ length: 100, nullable: true })
    email: string;

    @Column({ length: 500, nullable: true })
    website: string;

    // === HKD-specific fields ===
    @Column({ name: 'owner_name', length: 200, nullable: true })
    ownerName: string;

    @Column({ name: 'owner_identity_number', length: 20, nullable: true })
    ownerIdentityNumber: string;

    @Column({ name: 'business_license_number', length: 50, nullable: true })
    businessLicenseNumber: string;

    @Column({ name: 'costing_method', length: 10, default: 'AVG' })
    costingMethod: string; // FIFO | AVG

    // === Tax Configuration Fields ===
    @Column({ name: 'business_sector', length: 50, default: 'TRADE' })
    businessSector: string; // TRADE, SERVICE, PRODUCTION

    @Column({ name: 'apply_vat_reduction', default: false })
    applyVatReduction: boolean; // TRUE: giảm 20% mức tỷ lệ

    @Column({ name: 'custom_vat_rate', type: 'decimal', precision: 5, scale: 2, nullable: true })
    customVatRate: number; // nullable, use defaults if not set

    @Column({ name: 'custom_pit_rate', type: 'decimal', precision: 5, scale: 2, nullable: true })
    customPitRate: number; // nullable, use defaults if not set
}

@Entity('activity_logs')
export class ActivityLog {
    @PrimaryGeneratedColumn()
    id: number;

    @Column({ name: 'user_id' })
    userId: number;

    @Column({ name: 'shop_id', nullable: true })
    shopId: number;

    @Column({ length: 50 })
    action: string; // CREATE, UPDATE, DELETE, CANCEL, LOGIN, EXPORT, IMPORT

    @Column({ name: 'entity_type', length: 50 })
    entityType: string;

    @Column({ name: 'entity_id', nullable: true })
    entityId: number;

    @Column({ name: 'entity_name', length: 200, nullable: true })
    entityName: string;

    @Column({ name: 'old_value', length: 2000, nullable: true })
    oldValue: string;

    @Column({ name: 'new_value', length: 2000, nullable: true })
    newValue: string;

    @Column({ length: 500, nullable: true })
    description: string;

    @Column({ name: 'ip_address', length: 50, nullable: true })
    ipAddress: string;

    @CreateDateColumn({ name: 'created_at' })
    createdAt: Date;
}

@Entity('invoice_scans')
export class InvoiceScan {
    @PrimaryGeneratedColumn()
    id: number;

    @Column({ name: 'scan_code', unique: true, length: 20 })
    scanCode: string;

    @Column({ name: 'shop_id', nullable: true })
    shopId: number;

    @Column({ name: 'image_url', length: 1000 })
    imageUrl: string;

    @Column({ name: 'image_thumbnail_url', length: 1000, nullable: true })
    imageThumbnailUrl: string;

    @Column({ name: 'invoice_type', length: 20, default: 'PURCHASE' })
    invoiceType: string;

    @Column({ length: 20, default: 'PENDING' })
    status: string; // PENDING, PROCESSING, COMPLETED, FAILED, CONFIRMED

    @Column({ name: 'ocr_raw_text', type: 'text', nullable: true })
    ocrRawText: string;

    @Column({ name: 'ocr_parsed_data', type: 'text', nullable: true })
    ocrParsedData: string;

    @Column({ name: 'confirmed_data', type: 'text', nullable: true })
    confirmedData: string;

    @Column({ name: 'confidence_score', nullable: true })
    confidenceScore: number;

    @Column({ name: 'total_amount', type: 'decimal', precision: 18, scale: 2, nullable: true })
    totalAmount: number;

    @Column({ name: 'reference_type', length: 30, nullable: true })
    referenceType: string;

    @Column({ name: 'reference_id', nullable: true })
    referenceId: number;

    @Column({ name: 'ocr_engine', length: 50, default: 'GOOGLE_VISION' })
    ocrEngine: string;

    @Column({ name: 'scanned_by', nullable: true })
    scannedBy: number;

    @CreateDateColumn({ name: 'scanned_at' })
    scannedAt: Date;

    @Column({ name: 'confirmed_at', nullable: true })
    confirmedAt: Date;

    @Column({ length: 500, nullable: true })
    notes: string;
}

// === HÓA ĐƠN ĐẦU VÀO / ĐẦU RA ===
@Entity('invoices')
export class Invoice {
    @PrimaryGeneratedColumn()
    id: number;

    @Column({ name: 'invoice_number', length: 50 })
    invoiceNumber: string;

    @Column({ name: 'shop_id', nullable: true })
    shopId: number;

    @Column({ name: 'invoice_symbol', length: 20, nullable: true })
    invoiceSymbol: string;

    @Column({ name: 'invoice_type', length: 10 })
    invoiceType: string; // IN (đầu vào), OUT (đầu ra)

    @Column({ name: 'invoice_date', type: 'date' })
    invoiceDate: Date;

    // Thông tin đối tác
    @Column({ name: 'partner_name', length: 200 })
    partnerName: string;

    @Column({ name: 'partner_tax_code', length: 20, nullable: true })
    partnerTaxCode: string;

    @Column({ name: 'partner_address', length: 500, nullable: true })
    partnerAddress: string;

    @Column({ name: 'partner_identity_number', length: 20, nullable: true })
    partnerIdentityNumber: string;

    // Tham chiếu
    @Column({ name: 'reference_type', length: 30, nullable: true })
    referenceType: string; // PURCHASE_ORDER, SALES_ORDER

    @Column({ name: 'reference_id', nullable: true })
    referenceId: number;

    // Tổng tiền
    @Column({ type: 'decimal', precision: 18, scale: 2, default: 0 })
    subtotal: number;

    @Column({ name: 'tax_amount', type: 'decimal', precision: 18, scale: 2, default: 0 })
    taxAmount: number;

    @Column({ name: 'total_amount', type: 'decimal', precision: 18, scale: 2, default: 0 })
    totalAmount: number;

    @Column({ name: 'payment_method', length: 20, nullable: true })
    paymentMethod: string;

    @Column({ name: 'payment_status', length: 20, default: 'UNPAID' })
    paymentStatus: string; // UNPAID, PARTIAL, PAID

    @Column({ name: 'image_url', length: 1000, nullable: true })
    imageUrl: string;

    @Column({ length: 500, nullable: true })
    notes: string;

    @OneToMany(() => InvoiceItem, (i) => i.invoice, { cascade: true })
    items: InvoiceItem[];

    @Column({ name: 'created_by', nullable: true })
    createdBy: number;

    @CreateDateColumn({ name: 'created_at' })
    createdAt: Date;
}

@Entity('invoice_items')
export class InvoiceItem {
    @PrimaryGeneratedColumn()
    id: number;

    @ManyToOne(() => Invoice, (inv) => inv.items)
    @JoinColumn({ name: 'invoice_id' })
    invoice: Invoice;

    @ManyToOne(() => Product, { nullable: true })
    @JoinColumn({ name: 'product_id' })
    product: Product;

    @Column({ name: 'item_name', length: 200 })
    itemName: string;

    @Column({ length: 20, default: 'Cái' })
    unit: string;

    @Column()
    quantity: number;

    @Column({ name: 'unit_price', type: 'decimal', precision: 18, scale: 2 })
    unitPrice: number;

    @Column({ type: 'decimal', precision: 18, scale: 2 })
    subtotal: number;

    @Column({ name: 'tax_rate', type: 'decimal', precision: 5, scale: 2, default: 0 })
    taxRate: number;

    @Column({ name: 'tax_amount', type: 'decimal', precision: 18, scale: 2, default: 0 })
    taxAmount: number;
}

