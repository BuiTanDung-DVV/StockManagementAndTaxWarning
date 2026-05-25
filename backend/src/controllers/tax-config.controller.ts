import { Request, Response } from 'express';
import { AppDataSource } from '../config/db.config';
import { ShopProfile } from '../system/entities';

export const getTaxConfig = async (req: Request, res: Response) => {
    try {
        const shopId = (req as any).shopId;
        
        // Fetch shop configuration
        let shopConfig = null;
        if (shopId) {
            const shopRepo = AppDataSource.getRepository(ShopProfile);
            const shop = await shopRepo.findOne({ where: { shopId } });
            if (shop) {
                shopConfig = {
                    businessSector: shop.businessSector,
                    applyVatReduction: shop.applyVatReduction,
                    customVatRate: shop.customVatRate,
                    customPitRate: shop.customPitRate
                };
            }
        }

        // Cấu hình luật thuế HKD 2026
        const config: any = {
            fiscalYear: 2026,
            thresholds: {
                tier1: 100000000,   // 100M: Miễn thuế
                tier2: 300000000,   // 300M: Ngưỡng cảnh báo kê khai
                tier3: 500000000,   // 500M: Ngưỡng kê khai mới 2026
                tier4: 1000000000,  // 1 Tỷ: Bắt buộc HĐĐT
            },
            taxRates: {
                wholesale_retail: {
                    vat: 0.01, // 1%
                    pit: 0.005, // 0.5%
                },
                manufacturing_transport: {
                    vat: 0.03, // 3%
                    pit: 0.015, // 1.5%
                },
                services: {
                    vat: 0.05, // 5%
                    pit: 0.02, // 2%
                },
                other: {
                    vat: 0.02, // 2%
                    pit: 0.01, // 1%
                }
            },
            currentPolicies: {
                vatReductionActive: false, // Ví dụ: Không còn giảm 20% VAT trong 2026
                vatReductionRate: 0.0, 
            }
        };

        if (shopConfig) {
            config.shopConfig = shopConfig;
        }

        res.json({ success: true, data: config });
    } catch (error) {
        console.error('Error fetching tax config:', error);
        res.status(500).json({ success: false, message: 'Failed to fetch tax config' });
    }
};

export const updateTaxConfig = async (req: Request, res: Response) => {
    try {
        const shopId = (req as any).shopId;
        if (!shopId) return res.status(400).json({ success: false, message: 'Missing shopId' });

        const shopRepo = AppDataSource.getRepository(ShopProfile);
        let shop = await shopRepo.findOne({ where: { shopId } });
        if (!shop) {
            shop = shopRepo.create({ shopId, shopName: 'My Shop' });
        }
        
        if (req.body.businessSector !== undefined) shop.businessSector = req.body.businessSector;
        if (req.body.applyVatReduction !== undefined) shop.applyVatReduction = req.body.applyVatReduction;
        if (req.body.customVatRate !== undefined) shop.customVatRate = req.body.customVatRate;
        if (req.body.customPitRate !== undefined) shop.customPitRate = req.body.customPitRate;

        await shopRepo.save(shop);
        res.json({ success: true, data: shop });
    } catch (error) {
        console.error('Error updating tax config:', error);
        res.status(500).json({ success: false, message: 'Failed to update tax config' });
    }
};
