import { AppDataSource } from '../config/db.config';
import { ShopProfile, ActivityLog, AiKnowledgeDocument, InvoiceScan, Invoice } from '../system/entities';
import { PurchaseWithoutInvoice } from '../finance/entities';
import { ImageStorageService, ProductImageUploadRequest } from './image-storage.service';

export class SystemService {
    private profileRepo = AppDataSource.getRepository(ShopProfile);
    private logRepo = AppDataSource.getRepository(ActivityLog);
    private scanRepo = AppDataSource.getRepository(InvoiceScan);
    private invoiceRepo = AppDataSource.getRepository(Invoice);
    private pwioRepo = AppDataSource.getRepository(PurchaseWithoutInvoice);
    private aiKnowledgeRepo = AppDataSource.getRepository(AiKnowledgeDocument);
    private imageStorageService = new ImageStorageService();

    // Profile
    async getShopProfile(shopId: number) {
        const profile = await this.profileRepo.findOne({ where: { shopId } }) ??
            await this.profileRepo.findOne({ where: { id: shopId } });
        if (!profile) throw new Error('Shop profile not found');
        return profile;
    }

    async updateShopProfile(shopId: number, dto: Partial<ShopProfile>) {
        const profile = await this.getShopProfile(shopId);
        const { qrPaymentUrl: _managedByUploadFlow, ...safeDto } = dto;
        Object.assign(profile, safeDto);
        return this.profileRepo.save(profile);
    }

    async getShopPaymentQr(shopId: number) {
        const profile = await this.getShopProfile(shopId);
        return { imageUrl: profile.qrPaymentUrl || null };
    }

    async createShopPaymentQrUpload(
        shopId: number,
        request: ProductImageUploadRequest,
    ) {
        return this.imageStorageService.createShopPaymentQrUpload(shopId, request);
    }

    async confirmAndReplaceShopPaymentQr(shopId: number, objectKey: string) {
        const uploaded = await this.imageStorageService.confirmShopPaymentQr(
            shopId,
            objectKey,
        );
        const profile = await this.getShopProfile(shopId);
        const previousImageUrl = profile.qrPaymentUrl;

        try {
            profile.qrPaymentUrl = uploaded.imageUrl;
            await this.profileRepo.save(profile);
        } catch (error) {
            try {
                await this.imageStorageService.deleteShopPaymentQr(
                    shopId,
                    uploaded.objectKey,
                );
            } catch {
                // Cleanup is best effort if the profile update fails.
            }
            throw error;
        }

        if (previousImageUrl && previousImageUrl !== uploaded.imageUrl) {
            try {
                await this.imageStorageService.deleteShopPaymentQrByUrl(
                    shopId,
                    previousImageUrl,
                );
            } catch {
                // The new QR is already saved; old-object cleanup is best effort.
            }
        }

        return { imageUrl: uploaded.imageUrl };
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

    async getInvoiceScans(shopId: number, page = 1, limit = 20) {
        const safePage = Math.max(page, 1);
        const safeLimit = Math.min(Math.max(limit, 1), 100);
        const [items, total] = await this.scanRepo.findAndCount({
            where: { shopId },
            order: { scannedAt: 'DESC' },
            skip: (safePage - 1) * safeLimit,
            take: safeLimit,
        });
        return {
            items,
            total,
            page: safePage,
            limit: safeLimit,
            totalPages: Math.ceil(total / safeLimit),
        };
    }

    async createInvoiceScan(shopId: number, scannedBy: number | undefined, dto: Partial<InvoiceScan>) {
        const imageUrl = String(dto.imageUrl || '').trim();
        if (!imageUrl || imageUrl.length > 1000) {
            throw new Error('Validation: Invoice image URL is required');
        }
        const scanCode = `S${shopId}${Date.now().toString().slice(-12)}`;
        return this.scanRepo.save(this.scanRepo.create({
            shopId,
            scannedBy,
            scanCode,
            imageUrl,
            imageThumbnailUrl: dto.imageThumbnailUrl,
            invoiceType: dto.invoiceType || 'PURCHASE',
            status: 'PENDING',
            notes: dto.notes,
        }));
    }

    async updateInvoiceScan(shopId: number, id: number, dto: Partial<InvoiceScan>) {
        const scan = await this.scanRepo.findOne({ where: { id, shopId } });
        if (!scan) throw new Error('Invoice scan not found');
        const allowed: (keyof InvoiceScan)[] = [
            'status', 'ocrRawText', 'ocrParsedData', 'confirmedData',
            'confidenceScore', 'totalAmount', 'referenceType', 'referenceId',
            'ocrEngine', 'confirmedAt', 'notes',
        ];
        for (const key of allowed) {
            if (dto[key] !== undefined) (scan as any)[key] = dto[key];
        }
        return this.scanRepo.save(scan);
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

    async getAiKnowledgeDocuments(shopId: number) {
        return this.aiKnowledgeRepo.find({
            where: { shopId },
            order: { createdAt: 'DESC' },
        });
    }

    async createAiKnowledgeDocument(
        shopId: number,
        createdBy: number | undefined,
        dto: Partial<AiKnowledgeDocument>,
    ) {
        const title = String(dto.title || '').trim();
        const category = String(dto.category || '').trim();
        const content = String(dto.content || '').trim();
        if (!title || !category || !content) {
            throw new Error('Validation: Title, category and content are required');
        }
        if (title.length > 200 || category.length > 100 || content.length > 100000) {
            throw new Error('Validation: AI knowledge document is too long');
        }
        return this.aiKnowledgeRepo.save(this.aiKnowledgeRepo.create({
            shopId,
            createdBy,
            title,
            category,
            content,
            isActive: dto.isActive !== false,
        }));
    }

    async updateAiKnowledgeDocument(
        shopId: number,
        id: number,
        dto: Partial<AiKnowledgeDocument>,
    ) {
        const document = await this.aiKnowledgeRepo.findOne({ where: { id, shopId } });
        if (!document) throw new Error('AI knowledge document not found');
        if (dto.title !== undefined) document.title = String(dto.title).trim();
        if (dto.category !== undefined) document.category = String(dto.category).trim();
        if (dto.content !== undefined) document.content = String(dto.content).trim();
        if (dto.isActive !== undefined) document.isActive = Boolean(dto.isActive);
        if (!document.title || !document.category || !document.content) {
            throw new Error('Validation: Title, category and content are required');
        }
        return this.aiKnowledgeRepo.save(document);
    }

    async deleteAiKnowledgeDocument(shopId: number, id: number) {
        const document = await this.aiKnowledgeRepo.findOne({ where: { id, shopId } });
        if (!document) throw new Error('AI knowledge document not found');
        await this.aiKnowledgeRepo.remove(document);
        return { id };
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

