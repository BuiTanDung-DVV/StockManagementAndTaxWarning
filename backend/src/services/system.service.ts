import { AppDataSource } from '../config/db.config';
import { ShopProfile, ActivityLog, InvoiceScan, Invoice, InvoiceItem, PurchaseWithoutInvoice, PurchaseWithoutInvoiceItem } from '../system/entities';

export class SystemService {
    private profileRepo = AppDataSource.getRepository(ShopProfile);
    private logRepo = AppDataSource.getRepository(ActivityLog);
    private scanRepo = AppDataSource.getRepository(InvoiceScan);
    private invoiceRepo = AppDataSource.getRepository(Invoice);
    private pwioRepo = AppDataSource.getRepository(PurchaseWithoutInvoice);

    // Profile
    async getShopProfile(shopId: number) {
        const profile = await this.profileRepo.findOne({ where: { id: shopId } });
        if (!profile) throw new Error('Shop profile not found');
        return profile;
    }

    async updateShopProfile(shopId: number, dto: Partial<ShopProfile>) {
        const profile = await this.getShopProfile(shopId);
        Object.assign(profile, dto);
        return this.profileRepo.save(profile);
    }

    // Activity Log
    async getActivityLogs(shopId: number, page: number = 1, limit: number = 20) {
        const [items, total] = await this.logRepo.findAndCount({
            where: { shopId } as any,
            skip: (page - 1) * limit,
            take: limit,
            order: { createdAt: 'DESC' },
        });
        return { items, total, page, limit, totalPages: Math.ceil(total / limit) };
    }

    // Invoices
    async getInvoices(shopId: number, page: number = 1, limit: number = 20) {
        const [items, total] = await this.invoiceRepo.findAndCount({
            where: { shopId } as any,
            skip: (page - 1) * limit,
            take: limit,
            order: { invoiceDate: 'DESC' },
        });
        return { items, total, page, limit, totalPages: Math.ceil(total / limit) };
    }

    async scanInvoice(shopId: number, dto: any) {
        return this.scanRepo.save(this.scanRepo.create({ ...dto, shopId, scanCode: 'SCN' + Date.now().toString().slice(-6) }));
    }

    // Purchases without Invoice
    async getPurchaseWithoutInvoice(shopId: number, page: number = 1, limit: number = 20) {
        const [items, total] = await this.pwioRepo.findAndCount({
            where: { shopId } as any,
            skip: (page - 1) * limit,
            take: limit,
            order: { purchaseDate: 'DESC' },
        });
        return { items, total, page, limit, totalPages: Math.ceil(total / limit) };
    }
}

