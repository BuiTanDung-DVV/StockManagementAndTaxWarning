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
exports.DebtPaymentHistory = exports.DebtEvidence = exports.Receivable = exports.Customer = void 0;
const typeorm_1 = require("typeorm");
let Customer = class Customer {
};
exports.Customer = Customer;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)(),
    __metadata("design:type", Number)
], Customer.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ unique: true, length: 20 }),
    __metadata("design:type", String)
], Customer.prototype, "code", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 200 }),
    __metadata("design:type", String)
], Customer.prototype, "name", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 20, nullable: true }),
    __metadata("design:type", String)
], Customer.prototype, "phone", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 100, nullable: true }),
    __metadata("design:type", String)
], Customer.prototype, "email", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 500, nullable: true }),
    __metadata("design:type", String)
], Customer.prototype, "address", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'tax_code', length: 20, nullable: true }),
    __metadata("design:type", String)
], Customer.prototype, "taxCode", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'identity_number', length: 20, nullable: true }),
    __metadata("design:type", String)
], Customer.prototype, "identityNumber", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'identity_image_url', length: 1000, nullable: true }),
    __metadata("design:type", String)
], Customer.prototype, "identityImageUrl", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'avatar_url', length: 1000, nullable: true }),
    __metadata("design:type", String)
], Customer.prototype, "avatarUrl", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'date_of_birth', type: 'date', nullable: true }),
    __metadata("design:type", Date)
], Customer.prototype, "dateOfBirth", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'customer_type', length: 20, default: 'RETAIL' }),
    __metadata("design:type", String)
], Customer.prototype, "customerType", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'zalo_phone', length: 20, nullable: true }),
    __metadata("design:type", String)
], Customer.prototype, "zaloPhone", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'credit_limit', type: 'decimal', precision: 18, scale: 2, default: 0 }),
    __metadata("design:type", Number)
], Customer.prototype, "creditLimit", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'decimal', precision: 18, scale: 2, default: 0 }),
    __metadata("design:type", Number)
], Customer.prototype, "balance", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 500, nullable: true }),
    __metadata("design:type", String)
], Customer.prototype, "notes", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'is_active', default: true }),
    __metadata("design:type", Boolean)
], Customer.prototype, "isActive", void 0);
__decorate([
    (0, typeorm_1.OneToMany)(() => Receivable, (r) => r.customer),
    __metadata("design:type", Array)
], Customer.prototype, "receivables", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'created_at' }),
    __metadata("design:type", Date)
], Customer.prototype, "createdAt", void 0);
__decorate([
    (0, typeorm_1.UpdateDateColumn)({ name: 'updated_at' }),
    __metadata("design:type", Date)
], Customer.prototype, "updatedAt", void 0);
exports.Customer = Customer = __decorate([
    (0, typeorm_1.Entity)('customers')
], Customer);
let Receivable = class Receivable {
};
exports.Receivable = Receivable;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)(),
    __metadata("design:type", Number)
], Receivable.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => Customer, (c) => c.receivables),
    (0, typeorm_1.JoinColumn)({ name: 'customer_id' }),
    __metadata("design:type", Customer)
], Receivable.prototype, "customer", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'order_id', nullable: true }),
    __metadata("design:type", Number)
], Receivable.prototype, "orderId", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'decimal', precision: 18, scale: 2 }),
    __metadata("design:type", Number)
], Receivable.prototype, "amount", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'paid_amount', type: 'decimal', precision: 18, scale: 2, default: 0 }),
    __metadata("design:type", Number)
], Receivable.prototype, "paidAmount", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'due_date', type: 'date' }),
    __metadata("design:type", Date)
], Receivable.prototype, "dueDate", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 20, default: 'UNPAID' }),
    __metadata("design:type", String)
], Receivable.prototype, "status", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'remaining_amount', type: 'decimal', precision: 18, scale: 2, nullable: true, insert: false, update: false }),
    __metadata("design:type", Number)
], Receivable.prototype, "remainingAmount", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 500, nullable: true }),
    __metadata("design:type", String)
], Receivable.prototype, "notes", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'debt_reason', length: 500, nullable: true }),
    __metadata("design:type", String)
], Receivable.prototype, "debtReason", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'witness_name', length: 200, nullable: true }),
    __metadata("design:type", String)
], Receivable.prototype, "witnessName", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'reminder_enabled', default: false }),
    __metadata("design:type", Boolean)
], Receivable.prototype, "reminderEnabled", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'last_reminder_at', nullable: true }),
    __metadata("design:type", Date)
], Receivable.prototype, "lastReminderAt", void 0);
__decorate([
    (0, typeorm_1.OneToMany)(() => DebtEvidence, (e) => e.receivable, { cascade: true }),
    __metadata("design:type", Array)
], Receivable.prototype, "evidences", void 0);
__decorate([
    (0, typeorm_1.OneToMany)(() => DebtPaymentHistory, (p) => p.receivable, { cascade: true }),
    __metadata("design:type", Array)
], Receivable.prototype, "paymentHistory", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'created_at' }),
    __metadata("design:type", Date)
], Receivable.prototype, "createdAt", void 0);
__decorate([
    (0, typeorm_1.UpdateDateColumn)({ name: 'updated_at' }),
    __metadata("design:type", Date)
], Receivable.prototype, "updatedAt", void 0);
exports.Receivable = Receivable = __decorate([
    (0, typeorm_1.Entity)('receivables')
], Receivable);
let DebtEvidence = class DebtEvidence {
};
exports.DebtEvidence = DebtEvidence;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)(),
    __metadata("design:type", Number)
], DebtEvidence.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => Receivable, (r) => r.evidences, { nullable: true }),
    (0, typeorm_1.JoinColumn)({ name: 'receivable_id' }),
    __metadata("design:type", Receivable)
], DebtEvidence.prototype, "receivable", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'payable_id', nullable: true }),
    __metadata("design:type", Number)
], DebtEvidence.prototype, "payableId", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 20 }),
    __metadata("design:type", String)
], DebtEvidence.prototype, "type", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'file_url', length: 1000 }),
    __metadata("design:type", String)
], DebtEvidence.prototype, "fileUrl", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'file_name', length: 200, nullable: true }),
    __metadata("design:type", String)
], DebtEvidence.prototype, "fileName", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'file_size', type: 'bigint', nullable: true }),
    __metadata("design:type", Number)
], DebtEvidence.prototype, "fileSize", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 500, nullable: true }),
    __metadata("design:type", String)
], DebtEvidence.prototype, "description", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'uploaded_by', nullable: true }),
    __metadata("design:type", Number)
], DebtEvidence.prototype, "uploadedBy", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'uploaded_at' }),
    __metadata("design:type", Date)
], DebtEvidence.prototype, "uploadedAt", void 0);
exports.DebtEvidence = DebtEvidence = __decorate([
    (0, typeorm_1.Entity)('debt_evidences')
], DebtEvidence);
let DebtPaymentHistory = class DebtPaymentHistory {
};
exports.DebtPaymentHistory = DebtPaymentHistory;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)(),
    __metadata("design:type", Number)
], DebtPaymentHistory.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => Receivable, (r) => r.paymentHistory, { nullable: true }),
    (0, typeorm_1.JoinColumn)({ name: 'receivable_id' }),
    __metadata("design:type", Receivable)
], DebtPaymentHistory.prototype, "receivable", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'payable_id', nullable: true }),
    __metadata("design:type", Number)
], DebtPaymentHistory.prototype, "payableId", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'decimal', precision: 18, scale: 2 }),
    __metadata("design:type", Number)
], DebtPaymentHistory.prototype, "amount", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'payment_method', length: 20, default: 'CASH' }),
    __metadata("design:type", String)
], DebtPaymentHistory.prototype, "paymentMethod", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'payment_date' }),
    __metadata("design:type", Date)
], DebtPaymentHistory.prototype, "paymentDate", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'evidence_url', length: 1000, nullable: true }),
    __metadata("design:type", String)
], DebtPaymentHistory.prototype, "evidenceUrl", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 500, nullable: true }),
    __metadata("design:type", String)
], DebtPaymentHistory.prototype, "notes", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'recorded_by', nullable: true }),
    __metadata("design:type", Number)
], DebtPaymentHistory.prototype, "recordedBy", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'created_at' }),
    __metadata("design:type", Date)
], DebtPaymentHistory.prototype, "createdAt", void 0);
exports.DebtPaymentHistory = DebtPaymentHistory = __decorate([
    (0, typeorm_1.Entity)('debt_payment_history')
], DebtPaymentHistory);
//# sourceMappingURL=entities.js.map