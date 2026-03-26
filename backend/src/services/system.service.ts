import { AppDataSource } from '../config/db.config';
import { ShopProfile, ActivityLog, InvoiceScan, Invoice, InvoiceItem, PurchaseWithoutInvoice, PurchaseWithoutInvoiceItem } from '../system/entities';

export class SystemService {
    private profileRepo = AppDataSource.getRepository(ShopProfile);
    private logRepo = AppDataSource.getRepository(ActivityLog);
    private scanRepo = AppDataSource.getRepository(InvoiceScan);
    private invoiceRepo = AppDataSource.getRepository(Invoice);
    private pwioRepo = AppDataSource.getRepository(PurchaseWithoutInvoice);

    // Profile
    async getShopProfile(id: number = 1) { // Defaulting to 1 for generic single-tenant
        let profile = await this.profileRepo.findOne({ where: { id } });
        if (!profile) {
            profile = this.profileRepo.create({ shopName: 'My Shop' });
            await this.profileRepo.save(profile);
        }
        return profile;
    }

    async updateShopProfile(id: number = 1, dto: Partial<ShopProfile>) {
        const profile = await this.getShopProfile(id);
        Object.assign(profile, dto);
        return this.profileRepo.save(profile);
    }

    // Activity Log
    async getActivityLogs(page: number = 1, limit: number = 20) {
        const [items, total] = await this.logRepo.findAndCount({ skip: (page - 1) * limit, take: limit, order: { createdAt: 'DESC' } });
        return { items, total, page, limit, totalPages: Math.ceil(total / limit) };
    }

    // Invoices
    async getInvoices(page: number = 1, limit: number = 20) {
        const [items, total] = await this.invoiceRepo.findAndCount({ skip: (page - 1) * limit, take: limit, order: { invoiceDate: 'DESC' } });
        return { items, total, page, limit, totalPages: Math.ceil(total / limit) };
    }

    async scanInvoice(dto: any) {
        return this.scanRepo.save(this.scanRepo.create({ ...dto, scanCode: 'SCN' + Date.now().toString().slice(-6) }));
    }

    // Purchases without Invoice
    async getPurchaseWithoutInvoice(page: number = 1, limit: number = 20) {
        const [items, total] = await this.pwioRepo.findAndCount({ skip: (page - 1) * limit, take: limit, order: { purchaseDate: 'DESC' } });
        return { items, total, page, limit, totalPages: Math.ceil(total / limit) };
    }
}
