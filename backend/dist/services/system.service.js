"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.SystemService = void 0;
const db_config_1 = require("../config/db.config");
const entities_1 = require("../system/entities");
class SystemService {
    constructor() {
        this.profileRepo = db_config_1.AppDataSource.getRepository(entities_1.ShopProfile);
        this.logRepo = db_config_1.AppDataSource.getRepository(entities_1.ActivityLog);
        this.scanRepo = db_config_1.AppDataSource.getRepository(entities_1.InvoiceScan);
        this.invoiceRepo = db_config_1.AppDataSource.getRepository(entities_1.Invoice);
        this.pwioRepo = db_config_1.AppDataSource.getRepository(entities_1.PurchaseWithoutInvoice);
    }
    async getShopProfile(id = 1) {
        let profile = await this.profileRepo.findOne({ where: { id } });
        if (!profile) {
            profile = this.profileRepo.create({ shopName: 'My Shop' });
            await this.profileRepo.save(profile);
        }
        return profile;
    }
    async updateShopProfile(id = 1, dto) {
        const profile = await this.getShopProfile(id);
        Object.assign(profile, dto);
        return this.profileRepo.save(profile);
    }
    async getActivityLogs(page = 1, limit = 20) {
        const [items, total] = await this.logRepo.findAndCount({ skip: (page - 1) * limit, take: limit, order: { createdAt: 'DESC' } });
        return { items, total, page, limit, totalPages: Math.ceil(total / limit) };
    }
    async getInvoices(page = 1, limit = 20) {
        const [items, total] = await this.invoiceRepo.findAndCount({ skip: (page - 1) * limit, take: limit, order: { invoiceDate: 'DESC' } });
        return { items, total, page, limit, totalPages: Math.ceil(total / limit) };
    }
    async scanInvoice(dto) {
        return this.scanRepo.save(this.scanRepo.create({ ...dto, scanCode: 'SCN' + Date.now().toString().slice(-6) }));
    }
    async getPurchaseWithoutInvoice(page = 1, limit = 20) {
        const [items, total] = await this.pwioRepo.findAndCount({ skip: (page - 1) * limit, take: limit, order: { purchaseDate: 'DESC' } });
        return { items, total, page, limit, totalPages: Math.ceil(total / limit) };
    }
}
exports.SystemService = SystemService;
//# sourceMappingURL=system.service.js.map