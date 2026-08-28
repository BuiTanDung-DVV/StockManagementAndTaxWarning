import { Request, Response } from 'express';
import { AppDataSource } from '../config/db.config';
import { ShopProfile } from '../system/entities';
import {
    taxPolicyService,
    TaxPolicyConfigurationError,
} from '../services/tax-policy.service';

const taxConfigurationMessage =
    'Chức năng thuế chưa sẵn sàng. Vui lòng hoàn tất cấu hình thuế hoặc thử lại sau.';

export const getTaxConfig = async (req: Request, res: Response) => {
    try {
        const shopId = (req as any).shopId;
        
        const config = await taxPolicyService.getShopTaxConfiguration(shopId);
        res.json({ success: true, data: config });
    } catch (error) {
        console.error('Error fetching tax config:', error);
        const status = error instanceof TaxPolicyConfigurationError ? 503 : 500;
        res.status(status).json({
            success: false,
            message: error instanceof TaxPolicyConfigurationError
                ? taxConfigurationMessage
                : 'Không thể tải cấu hình thuế. Vui lòng thử lại.',
        });
    }
};

export const updateTaxConfig = async (req: Request, res: Response) => {
    try {
        const shopId = (req as any).shopId;
        if (!shopId) return res.status(400).json({ success: false, message: 'Missing shopId' });

        const shopRepo = AppDataSource.getRepository(ShopProfile);
        const shop = await shopRepo.findOne({ where: { shopId } });
        if (!shop) {
            return res.status(404).json({ success: false, message: 'Không tìm thấy hồ sơ cửa hàng' });
        }
        
        if (req.body.businessSector !== undefined) shop.businessSector = req.body.businessSector;
        if (req.body.customVatRate !== undefined) shop.customVatRate = req.body.customVatRate;
        if (req.body.customPitRate !== undefined) shop.customPitRate = req.body.customPitRate;

        await shopRepo.save(shop);
        res.json({ success: true, data: shop });
    } catch (error) {
        console.error('Error updating tax config:', error);
        res.status(500).json({ success: false, message: 'Failed to update tax config' });
    }
};
