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
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.SystemService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const entities_1 = require("./entities");
let SystemService = class SystemService {
    constructor(shopRepo, logRepo, scanRepo, invoiceRepo, invoiceItemRepo, pwiRepo, pwiItemRepo) {
        this.shopRepo = shopRepo;
        this.logRepo = logRepo;
        this.scanRepo = scanRepo;
        this.invoiceRepo = invoiceRepo;
        this.invoiceItemRepo = invoiceItemRepo;
        this.pwiRepo = pwiRepo;
        this.pwiItemRepo = pwiItemRepo;
    }
    async getShopProfile() {
        const profiles = await this.shopRepo.find();
        return profiles[0] || null;
    }
    async saveShopProfile(dto) {
        const existing = await this.getShopProfile();
        if (existing) {
            Object.assign(existing, dto);
            return this.shopRepo.save(existing);
        }
        return this.shopRepo.save(this.shopRepo.create(dto));
    }
    async log(action, entityType, entityId, entityName, description, userId) {
        return this.logRepo.save(this.logRepo.create({ action, entityType, entityId, entityName, description, userId }));
    }
    async getLogs(page = 1, limit = 50) {
        const [items, total] = await this.logRepo.findAndCount({
            skip: (page - 1) * limit, take: limit, order: { createdAt: 'DESC' },
        });
        return { items, total, page, limit };
    }
    async createScan(dto) {
        if (!dto.scanCode)
            dto.scanCode = 'SC' + Date.now().toString().slice(-8);
        return this.scanRepo.save(this.scanRepo.create(dto));
    }
    async updateScan(id, dto) {
        const scan = await this.scanRepo.findOne({ where: { id } });
        if (!scan)
            throw new common_1.NotFoundException('Scan not found');
        Object.assign(scan, dto);
        return this.scanRepo.save(scan);
    }
    async findScans(page = 1, limit = 20) {
        const [items, total] = await this.scanRepo.findAndCount({
            skip: (page - 1) * limit, take: limit, order: { scannedAt: 'DESC' },
        });
        return { items, total, page, limit };
    }
    async findInvoices(page = 1, limit = 20, type, from, to) {
        const qb = this.invoiceRepo.createQueryBuilder('i')
            .leftJoinAndSelect('i.items', 'items')
            .orderBy('i.createdAt', 'DESC');
        if (type)
            qb.andWhere('i.invoiceType = :type', { type });
        if (from && to)
            qb.andWhere('i.invoiceDate BETWEEN :from AND :to', { from, to });
        const [items, total] = await qb.skip((page - 1) * limit).take(limit).getManyAndCount();
        return { items, total, page, limit };
    }
    async findInvoiceById(id) {
        const invoice = await this.invoiceRepo.findOne({ where: { id }, relations: ['items', 'items.product'] });
        if (!invoice)
            throw new common_1.NotFoundException('Invoice not found');
        return invoice;
    }
    async createInvoice(dto) {
        let subtotal = 0;
        let taxAmount = 0;
        const invoiceItems = (dto.items || []).map((i) => {
            const sub = i.quantity * i.unitPrice;
            const tax = sub * (i.taxRate || 0) / 100;
            subtotal += sub;
            taxAmount += tax;
            return this.invoiceItemRepo.create({
                itemName: i.itemName, unit: i.unit, quantity: i.quantity,
                unitPrice: i.unitPrice, subtotal: sub, taxRate: i.taxRate || 0, taxAmount: tax,
                product: i.productId ? { id: i.productId } : undefined,
            });
        });
        const invoice = this.invoiceRepo.create({
            ...dto, subtotal, taxAmount, totalAmount: subtotal + taxAmount, items: invoiceItems,
        });
        return this.invoiceRepo.save(invoice);
    }
    async getInvoiceSummary(from, to) {
        const inSummary = await this.invoiceRepo.createQueryBuilder('i')
            .select('COUNT(i.id)', 'count')
            .addSelect('COALESCE(SUM(i.subtotal), 0)', 'subtotal')
            .addSelect('COALESCE(SUM(i.taxAmount), 0)', 'taxAmount')
            .addSelect('COALESCE(SUM(i.totalAmount), 0)', 'totalAmount')
            .where('i.invoiceType = :type', { type: 'IN' })
            .andWhere('i.invoiceDate BETWEEN :from AND :to', { from, to })
            .getRawOne();
        const outSummary = await this.invoiceRepo.createQueryBuilder('i')
            .select('COUNT(i.id)', 'count')
            .addSelect('COALESCE(SUM(i.subtotal), 0)', 'subtotal')
            .addSelect('COALESCE(SUM(i.taxAmount), 0)', 'taxAmount')
            .addSelect('COALESCE(SUM(i.totalAmount), 0)', 'totalAmount')
            .where('i.invoiceType = :type', { type: 'OUT' })
            .andWhere('i.invoiceDate BETWEEN :from AND :to', { from, to })
            .getRawOne();
        return {
            period: { from, to },
            input: inSummary,
            output: outSummary,
            taxBalance: Number(outSummary.taxAmount) - Number(inSummary.taxAmount),
        };
    }
    async findPurchasesWithoutInvoice(page = 1, limit = 20) {
        const [items, total] = await this.pwiRepo.findAndCount({
            relations: ['items'], skip: (page - 1) * limit, take: limit, order: { createdAt: 'DESC' },
        });
        return { items, total, page, limit };
    }
    async createPurchaseWithoutInvoice(dto) {
        const recordCode = 'BK' + Date.now().toString().slice(-8);
        let totalAmount = 0;
        const items = (dto.items || []).map((i) => {
            const sub = i.quantity * i.unitPrice;
            totalAmount += sub;
            return this.pwiItemRepo.create({ itemName: i.itemName, unit: i.unit || 'Kg', quantity: i.quantity, unitPrice: i.unitPrice, subtotal: sub });
        });
        return this.pwiRepo.save(this.pwiRepo.create({ ...dto, recordCode, totalAmount, items }));
    }
};
exports.SystemService = SystemService;
exports.SystemService = SystemService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(entities_1.ShopProfile)),
    __param(1, (0, typeorm_1.InjectRepository)(entities_1.ActivityLog)),
    __param(2, (0, typeorm_1.InjectRepository)(entities_1.InvoiceScan)),
    __param(3, (0, typeorm_1.InjectRepository)(entities_1.Invoice)),
    __param(4, (0, typeorm_1.InjectRepository)(entities_1.InvoiceItem)),
    __param(5, (0, typeorm_1.InjectRepository)(entities_1.PurchaseWithoutInvoice)),
    __param(6, (0, typeorm_1.InjectRepository)(entities_1.PurchaseWithoutInvoiceItem)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository])
], SystemService);
//# sourceMappingURL=system.service.js.map