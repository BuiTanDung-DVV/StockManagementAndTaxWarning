import { AppDataSource } from '../config/db.config';
import { ShopProfile, ActivityLog, InvoiceScan, Invoice, InvoiceItem } from '../system/entities';
import { PurchaseWithoutInvoice, PurchaseWithoutInvoiceItem } from '../finance/entities';

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

    // Dynamic Configurations
    async getSystemConfig(shopId: number, key: string, defaultValue: string): Promise<string> {
        try {
            await AppDataSource.query(`
                CREATE TABLE IF NOT EXISTS system_configs (
                    id SERIAL PRIMARY KEY,
                    shop_id INT NULL,
                    config_key VARCHAR(100) UNIQUE NOT NULL,
                    config_value VARCHAR(500) NOT NULL,
                    description VARCHAR(500) NULL
                );
            `);

            const rows = await AppDataSource.query(
                `SELECT config_value FROM system_configs WHERE (shop_id = $1 OR shop_id IS NULL) AND config_key = $2 ORDER BY shop_id DESC LIMIT 1`,
                [shopId, key]
            );

            if (rows && rows.length > 0) {
                return rows[0].config_value;
            }

            await AppDataSource.query(
                `INSERT INTO system_configs (shop_id, config_key, config_value, description) 
                 VALUES (NULL, $1, $2, 'Default system configuration') 
                 ON CONFLICT (config_key) DO NOTHING`,
                [key, defaultValue]
            );

            return defaultValue;
        } catch (e) {
            console.error('Error fetching system config, falling back to default:', e);
            return defaultValue;
        }
    }

    async setSystemConfig(shopId: number, key: string, value: string): Promise<void> {
        await AppDataSource.query(`
            CREATE TABLE IF NOT EXISTS system_configs (
                id SERIAL PRIMARY KEY,
                shop_id INT NULL,
                config_key VARCHAR(100) UNIQUE NOT NULL,
                config_value VARCHAR(500) NOT NULL,
                description VARCHAR(500) NULL
            );
        `);

        await AppDataSource.query(
            `INSERT INTO system_configs (shop_id, config_key, config_value) 
             VALUES ($1, $2, $3) 
             ON CONFLICT (config_key) DO UPDATE SET config_value = EXCLUDED.config_value`,
            [shopId, key, value]
        );
    }
}

