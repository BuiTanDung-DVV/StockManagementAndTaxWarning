"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.PurchaseWithoutInvoiceItem = exports.PurchaseWithoutInvoice = exports.InvoiceItem = exports.Invoice = exports.InvoiceScan = exports.ActivityLog = exports.ShopProfile = void 0;
const typeorm_1 = require("typeorm");
const entities_1 = require("../product/entities");
let ShopProfile = class ShopProfile {
};
exports.ShopProfile = ShopProfile;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)(),
    __metadata("design:type", Number)
], ShopProfile.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'shop_name', length: 200 }),
    __metadata("design:type", String)
], ShopProfile.prototype, "shopName", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'logo_url', length: 1000, nullable: true }),
    __metadata("design:type", String)
], ShopProfile.prototype, "logoUrl", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 20, nullable: true }),
    __metadata("design:type", String)
], ShopProfile.prototype, "phone", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 500, nullable: true }),
    __metadata("design:type", String)
], ShopProfile.prototype, "address", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'tax_code', length: 20, nullable: true }),
    __metadata("design:type", String)
], ShopProfile.prototype, "taxCode", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'bank_account', length: 30, nullable: true }),
    __metadata("design:type", String)
], ShopProfile.prototype, "bankAccount", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'bank_name', length: 100, nullable: true }),
    __metadata("design:type", String)
], ShopProfile.prototype, "bankName", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'account_holder', length: 200, nullable: true }),
    __metadata("design:type", String)
], ShopProfile.prototype, "accountHolder", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'qr_payment_url', length: 1000, nullable: true }),
    __metadata("design:type", String)
], ShopProfile.prototype, "qrPaymentUrl", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'receipt_footer', length: 500, nullable: true }),
    __metadata("design:type", String)
], ShopProfile.prototype, "receiptFooter", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 100, nullable: true }),
    __metadata("design:type", String)
], ShopProfile.prototype, "email", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 500, nullable: true }),
    __metadata("design:type", String)
], ShopProfile.prototype, "website", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'owner_name', length: 200, nullable: true }),
    __metadata("design:type", String)
], ShopProfile.prototype, "ownerName", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'owner_identity_number', length: 20, nullable: true }),
    __metadata("design:type", String)
], ShopProfile.prototype, "ownerIdentityNumber", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'business_license_number', length: 50, nullable: true }),
    __metadata("design:type", String)
], ShopProfile.prototype, "businessLicenseNumber", void 0);
exports.ShopProfile = ShopProfile = __decorate([
    (0, typeorm_1.Entity)('shop_profiles')
], ShopProfile);
let ActivityLog = class ActivityLog {
};
exports.ActivityLog = ActivityLog;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)(),
    __metadata("design:type", Number)
], ActivityLog.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'user_id' }),
    __metadata("design:type", Number)
], ActivityLog.prototype, "userId", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 50 }),
    __metadata("design:type", String)
], ActivityLog.prototype, "action", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'entity_type', length: 50 }),
    __metadata("design:type", String)
], ActivityLog.prototype, "entityType", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'entity_id', nullable: true }),
    __metadata("design:type", Number)
], ActivityLog.prototype, "entityId", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'entity_name', length: 200, nullable: true }),
    __metadata("design:type", String)
], ActivityLog.prototype, "entityName", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'old_value', length: 2000, nullable: true }),
    __metadata("design:type", String)
], ActivityLog.prototype, "oldValue", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'new_value', length: 2000, nullable: true }),
    __metadata("design:type", String)
], ActivityLog.prototype, "newValue", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 500, nullable: true }),
    __metadata("design:type", String)
], ActivityLog.prototype, "description", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'ip_address', length: 50, nullable: true }),
    __metadata("design:type", String)
], ActivityLog.prototype, "ipAddress", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'created_at' }),
    __metadata("design:type", Date)
], ActivityLog.prototype, "createdAt", void 0);
exports.ActivityLog = ActivityLog = __decorate([
    (0, typeorm_1.Entity)('activity_logs')
], ActivityLog);
let InvoiceScan = class InvoiceScan {
};
exports.InvoiceScan = InvoiceScan;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)(),
    __metadata("design:type", Number)
], InvoiceScan.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'scan_code', unique: true, length: 20 }),
    __metadata("design:type", String)
], InvoiceScan.prototype, "scanCode", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'image_url', length: 1000 }),
    __metadata("design:type", String)
], InvoiceScan.prototype, "imageUrl", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'image_thumbnail_url', length: 1000, nullable: true }),
    __metadata("design:type", String)
], InvoiceScan.prototype, "imageThumbnailUrl", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'invoice_type', length: 20, default: 'PURCHASE' }),
    __metadata("design:type", String)
], InvoiceScan.prototype, "invoiceType", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 20, default: 'PENDING' }),
    __metadata("design:type", String)
], InvoiceScan.prototype, "status", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'ocr_raw_text', type: 'nvarchar', length: 'MAX', nullable: true }),
    __metadata("design:type", String)
], InvoiceScan.prototype, "ocrRawText", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'ocr_parsed_data', type: 'nvarchar', length: 'MAX', nullable: true }),
    __metadata("design:type", String)
], InvoiceScan.prototype, "ocrParsedData", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'confirmed_data', type: 'nvarchar', length: 'MAX', nullable: true }),
    __metadata("design:type", String)
], InvoiceScan.prototype, "confirmedData", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'confidence_score', nullable: true }),
    __metadata("design:type", Number)
], InvoiceScan.prototype, "confidenceScore", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'total_amount', type: 'decimal', precision: 18, scale: 2, nullable: true }),
    __metadata("design:type", Number)
], InvoiceScan.prototype, "totalAmount", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'reference_type', length: 30, nullable: true }),
    __metadata("design:type", String)
], InvoiceScan.prototype, "referenceType", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'reference_id', nullable: true }),
    __metadata("design:type", Number)
], InvoiceScan.prototype, "referenceId", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'ocr_engine', length: 50, default: 'GOOGLE_VISION' }),
    __metadata("design:type", String)
], InvoiceScan.prototype, "ocrEngine", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'scanned_by', nullable: true }),
    __metadata("design:type", Number)
], InvoiceScan.prototype, "scannedBy", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'scanned_at' }),
    __metadata("design:type", Date)
], InvoiceScan.prototype, "scannedAt", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'confirmed_at', nullable: true }),
    __metadata("design:type", Date)
], InvoiceScan.prototype, "confirmedAt", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 500, nullable: true }),
    __metadata("design:type", String)
], InvoiceScan.prototype, "notes", void 0);
exports.InvoiceScan = InvoiceScan = __decorate([
    (0, typeorm_1.Entity)('invoice_scans')
], InvoiceScan);
let Invoice = class Invoice {
};
exports.Invoice = Invoice;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)(),
    __metadata("design:type", Number)
], Invoice.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'invoice_number', length: 50 }),
    __metadata("design:type", String)
], Invoice.prototype, "invoiceNumber", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'invoice_symbol', length: 20, nullable: true }),
    __metadata("design:type", String)
], Invoice.prototype, "invoiceSymbol", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'invoice_type', length: 10 }),
    __metadata("design:type", String)
], Invoice.prototype, "invoiceType", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'invoice_date', type: 'date' }),
    __metadata("design:type", Date)
], Invoice.prototype, "invoiceDate", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'partner_name', length: 200 }),
    __metadata("design:type", String)
], Invoice.prototype, "partnerName", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'partner_tax_code', length: 20, nullable: true }),
    __metadata("design:type", String)
], Invoice.prototype, "partnerTaxCode", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'partner_address', length: 500, nullable: true }),
    __metadata("design:type", String)
], Invoice.prototype, "partnerAddress", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'partner_identity_number', length: 20, nullable: true }),
    __metadata("design:type", String)
], Invoice.prototype, "partnerIdentityNumber", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'reference_type', length: 30, nullable: true }),
    __metadata("design:type", String)
], Invoice.prototype, "referenceType", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'reference_id', nullable: true }),
    __metadata("design:type", Number)
], Invoice.prototype, "referenceId", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'decimal', precision: 18, scale: 2, default: 0 }),
    __metadata("design:type", Number)
], Invoice.prototype, "subtotal", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'tax_amount', type: 'decimal', precision: 18, scale: 2, default: 0 }),
    __metadata("design:type", Number)
], Invoice.prototype, "taxAmount", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'total_amount', type: 'decimal', precision: 18, scale: 2, default: 0 }),
    __metadata("design:type", Number)
], Invoice.prototype, "totalAmount", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'payment_method', length: 20, nullable: true }),
    __metadata("design:type", String)
], Invoice.prototype, "paymentMethod", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'payment_status', length: 20, default: 'UNPAID' }),
    __metadata("design:type", String)
], Invoice.prototype, "paymentStatus", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'image_url', length: 1000, nullable: true }),
    __metadata("design:type", String)
], Invoice.prototype, "imageUrl", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 500, nullable: true }),
    __metadata("design:type", String)
], Invoice.prototype, "notes", void 0);
__decorate([
    (0, typeorm_1.OneToMany)(() => InvoiceItem, (i) => i.invoice, { cascade: true }),
    __metadata("design:type", Array)
], Invoice.prototype, "items", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'created_by', nullable: true }),
    __metadata("design:type", Number)
], Invoice.prototype, "createdBy", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'created_at' }),
    __metadata("design:type", Date)
], Invoice.prototype, "createdAt", void 0);
exports.Invoice = Invoice = __decorate([
    (0, typeorm_1.Entity)('invoices')
], Invoice);
let InvoiceItem = class InvoiceItem {
};
exports.InvoiceItem = InvoiceItem;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)(),
    __metadata("design:type", Number)
], InvoiceItem.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => Invoice, (inv) => inv.items),
    (0, typeorm_1.JoinColumn)({ name: 'invoice_id' }),
    __metadata("design:type", Invoice)
], InvoiceItem.prototype, "invoice", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => entities_1.Product, { nullable: true }),
    (0, typeorm_1.JoinColumn)({ name: 'product_id' }),
    __metadata("design:type", entities_1.Product)
], InvoiceItem.prototype, "product", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'item_name', length: 200 }),
    __metadata("design:type", String)
], InvoiceItem.prototype, "itemName", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 20, default: 'Cái' }),
    __metadata("design:type", String)
], InvoiceItem.prototype, "unit", void 0);
__decorate([
    (0, typeorm_1.Column)(),
    __metadata("design:type", Number)
], InvoiceItem.prototype, "quantity", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'unit_price', type: 'decimal', precision: 18, scale: 2 }),
    __metadata("design:type", Number)
], InvoiceItem.prototype, "unitPrice", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'decimal', precision: 18, scale: 2 }),
    __metadata("design:type", Number)
], InvoiceItem.prototype, "subtotal", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'tax_rate', type: 'decimal', precision: 5, scale: 2, default: 0 }),
    __metadata("design:type", Number)
], InvoiceItem.prototype, "taxRate", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'tax_amount', type: 'decimal', precision: 18, scale: 2, default: 0 }),
    __metadata("design:type", Number)
], InvoiceItem.prototype, "taxAmount", void 0);
exports.InvoiceItem = InvoiceItem = __decorate([
    (0, typeorm_1.Entity)('invoice_items')
], InvoiceItem);
let PurchaseWithoutInvoice = class PurchaseWithoutInvoice {
};
exports.PurchaseWithoutInvoice = PurchaseWithoutInvoice;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)(),
    __metadata("design:type", Number)
], PurchaseWithoutInvoice.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'record_code', unique: true, length: 20 }),
    __metadata("design:type", String)
], PurchaseWithoutInvoice.prototype, "recordCode", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'purchase_date', type: 'date' }),
    __metadata("design:type", Date)
], PurchaseWithoutInvoice.prototype, "purchaseDate", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'seller_name', length: 200 }),
    __metadata("design:type", String)
], PurchaseWithoutInvoice.prototype, "sellerName", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'seller_identity_number', length: 20 }),
    __metadata("design:type", String)
], PurchaseWithoutInvoice.prototype, "sellerIdentityNumber", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'seller_address', length: 500, nullable: true }),
    __metadata("design:type", String)
], PurchaseWithoutInvoice.prototype, "sellerAddress", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'seller_phone', length: 20, nullable: true }),
    __metadata("design:type", String)
], PurchaseWithoutInvoice.prototype, "sellerPhone", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'seller_signature_url', length: 1000, nullable: true }),
    __metadata("design:type", String)
], PurchaseWithoutInvoice.prototype, "sellerSignatureUrl", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'total_amount', type: 'decimal', precision: 18, scale: 2 }),
    __metadata("design:type", Number)
], PurchaseWithoutInvoice.prototype, "totalAmount", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'payment_method', length: 20, default: 'CASH' }),
    __metadata("design:type", String)
], PurchaseWithoutInvoice.prototype, "paymentMethod", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'payment_proof_url', length: 1000, nullable: true }),
    __metadata("design:type", String)
], PurchaseWithoutInvoice.prototype, "paymentProofUrl", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'market_price_reference', type: 'decimal', precision: 18, scale: 2, nullable: true }),
    __metadata("design:type", Number)
], PurchaseWithoutInvoice.prototype, "marketPriceReference", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 500, nullable: true }),
    __metadata("design:type", String)
], PurchaseWithoutInvoice.prototype, "notes", void 0);
__decorate([
    (0, typeorm_1.OneToMany)(() => PurchaseWithoutInvoiceItem, (i) => i.purchase, { cascade: true }),
    __metadata("design:type", Array)
], PurchaseWithoutInvoice.prototype, "items", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'approved_by', nullable: true }),
    __metadata("design:type", Number)
], PurchaseWithoutInvoice.prototype, "approvedBy", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'created_by', nullable: true }),
    __metadata("design:type", Number)
], PurchaseWithoutInvoice.prototype, "createdBy", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'created_at' }),
    __metadata("design:type", Date)
], PurchaseWithoutInvoice.prototype, "createdAt", void 0);
exports.PurchaseWithoutInvoice = PurchaseWithoutInvoice = __decorate([
    (0, typeorm_1.Entity)('purchases_without_invoice')
], PurchaseWithoutInvoice);
let PurchaseWithoutInvoiceItem = class PurchaseWithoutInvoiceItem {
};
exports.PurchaseWithoutInvoiceItem = PurchaseWithoutInvoiceItem;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)(),
    __metadata("design:type", Number)
], PurchaseWithoutInvoiceItem.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => PurchaseWithoutInvoice, (p) => p.items),
    (0, typeorm_1.JoinColumn)({ name: 'purchase_id' }),
    __metadata("design:type", PurchaseWithoutInvoice)
], PurchaseWithoutInvoiceItem.prototype, "purchase", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'item_name', length: 200 }),
    __metadata("design:type", String)
], PurchaseWithoutInvoiceItem.prototype, "itemName", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 20, default: 'Kg' }),
    __metadata("design:type", String)
], PurchaseWithoutInvoiceItem.prototype, "unit", void 0);
__decorate([
    (0, typeorm_1.Column)(),
    __metadata("design:type", Number)
], PurchaseWithoutInvoiceItem.prototype, "quantity", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'unit_price', type: 'decimal', precision: 18, scale: 2 }),
    __metadata("design:type", Number)
], PurchaseWithoutInvoiceItem.prototype, "unitPrice", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'decimal', precision: 18, scale: 2 }),
    __metadata("design:type", Number)
], PurchaseWithoutInvoiceItem.prototype, "subtotal", void 0);
exports.PurchaseWithoutInvoiceItem = PurchaseWithoutInvoiceItem = __decorate([
    (0, typeorm_1.Entity)('purchase_without_invoice_items')
], PurchaseWithoutInvoiceItem);
//# sourceMappingURL=entities.js.map