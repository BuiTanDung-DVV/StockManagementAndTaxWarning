import { Request, Response } from 'express';
import { SystemService } from '../services/system.service';
import { CURRENT_TAX_POLICY } from '../tax/tax-policy';
import { ImageStorageError } from '../services/image-storage.service';
import { AppDataSource } from '../config/db.config';

const systemService = new SystemService();

const paymentQrError = (res: Response, error: unknown) => {
    if (error instanceof ImageStorageError) {
        return res.status(error.statusCode).json({
            success: false,
            message: error.message,
        });
    }
    console.error('Shop payment QR error:', error);
    return res.status(500).json({
        success: false,
        message: 'Không thể xử lý ảnh QR của cửa hàng',
    });
};

export const getShopPaymentQr = async (req: Request, res: Response) => {
    try {
        if ((req as any).isAllShops || !(req as any).shopId) {
            return res.status(403).json({
                success: false,
                message: 'QR chỉ khả dụng khi chọn một cửa hàng cụ thể',
            });
        }
        const data = await systemService.getShopPaymentQr((req as any).shopId);
        return res.json({ success: true, data });
    } catch (error) {
        return paymentQrError(res, error);
    }
};

export const createShopPaymentQrUpload = async (req: Request, res: Response) => {
    try {
        const data = await systemService.createShopPaymentQrUpload(
            (req as any).shopId,
            req.body,
        );
        return res.json({ success: true, data });
    } catch (error) {
        return paymentQrError(res, error);
    }
};

export const confirmShopPaymentQrUpload = async (req: Request, res: Response) => {
    try {
        const data = await systemService.confirmAndReplaceShopPaymentQr(
            (req as any).shopId,
            String(req.body.objectKey || ''),
        );
        return res.json({ success: true, data });
    } catch (error) {
        return paymentQrError(res, error);
    }
};

export const getShopProfile = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await systemService.getShopProfile((req as any).shopId) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const saveShopProfile = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await systemService.updateShopProfile((req as any).shopId, req.body) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const getActivityLogs = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await systemService.getActivityLogs((req as any).shopId, +(req.query.page || 1), +(req.query.limit || 20)) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const getInvoiceScans = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await systemService.getInvoiceScans((req as any).shopId, +(req.query.page || 1), +(req.query.limit || 20)) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const createInvoiceScan = async (req: Request, res: Response) => {
    try {
        res.json({
            success: true,
            data: await systemService.createInvoiceScan(
                (req as any).shopId,
                (req as any).user?.sub,
                req.body,
            ),
        });
    }
    catch (e: any) {
        const validation = String(e.message || '').startsWith('Validation:');
        res.status(validation ? 400 : 500).json({ success: false, message: e.message });
    }
};

export const updateInvoiceScan = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await systemService.updateInvoiceScan((req as any).shopId, +req.params.id, req.body) }); }
    catch (e: any) {
        res.status(e.message === 'Invoice scan not found' ? 404 : 500)
            .json({ success: false, message: e.message });
    }
};

export const getAiKnowledgeDocuments = async (req: Request, res: Response) => {
    try {
        res.json({
            success: true,
            data: await systemService.getAiKnowledgeDocuments((req as any).shopId),
        });
    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
};

export const createAiKnowledgeDocument = async (req: Request, res: Response) => {
    try {
        res.json({
            success: true,
            data: await systemService.createAiKnowledgeDocument(
                (req as any).shopId,
                (req as any).user?.sub,
                req.body,
            ),
        });
    } catch (e: any) {
        const validation = String(e.message || '').startsWith('Validation:');
        res.status(validation ? 400 : 500).json({ success: false, message: e.message });
    }
};

export const updateAiKnowledgeDocument = async (req: Request, res: Response) => {
    try {
        res.json({
            success: true,
            data: await systemService.updateAiKnowledgeDocument(
                (req as any).shopId,
                +req.params.id,
                req.body,
            ),
        });
    } catch (e: any) {
        const notFound = e.message === 'AI knowledge document not found';
        const validation = String(e.message || '').startsWith('Validation:');
        res.status(notFound ? 404 : validation ? 400 : 500).json({ success: false, message: e.message });
    }
};

export const deleteAiKnowledgeDocument = async (req: Request, res: Response) => {
    try {
        res.json({
            success: true,
            data: await systemService.deleteAiKnowledgeDocument(
                (req as any).shopId,
                +req.params.id,
            ),
        });
    } catch (e: any) {
        res.status(e.message === 'AI knowledge document not found' ? 404 : 500)
            .json({ success: false, message: e.message });
    }
};

export const getConfigs = async (req: Request, res: Response) => {
    try {
        const shopId = (req as any).shopId;
        const cashPurchaseLimit = await systemService.getSystemConfig(shopId, 'CASH_PURCHASE_LIMIT', '20000000');
        
        res.json({
            success: true,
            data: {
                taxExemptionThreshold:
                    CURRENT_TAX_POLICY.taxExemptionThreshold,
                cashPurchaseLimit: Number(cashPurchaseLimit),
                warningRevenueThreshold:
                    CURRENT_TAX_POLICY.warningRevenueThreshold,
                taxPolicy: CURRENT_TAX_POLICY,
            }
        });
    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
};

export const saveConfigs = async (req: Request, res: Response) => {
    try {
        const shopId = (req as any).shopId;
        const {
            taxExemptionThreshold,
            cashPurchaseLimit,
            warningRevenueThreshold,
        } = req.body;

        if (
            taxExemptionThreshold !== undefined ||
            warningRevenueThreshold !== undefined
        ) {
            return res.status(400).json({
                success: false,
                message:
                    'Ngưỡng thuế hiện hành do hệ thống quản lý theo văn bản pháp luật và không thể sửa thủ công.',
            });
        }
        if (cashPurchaseLimit !== undefined) {
            await systemService.setSystemConfig(shopId, 'CASH_PURCHASE_LIMIT', String(cashPurchaseLimit));
        }
        
        res.json({ success: true, message: 'Cập nhật cấu hình hệ thống thành công' });
    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
};

export const seedProductionTestMedia = async (req: Request, res: Response) => {
    try {
        const userId = (req as any).user?.sub;
        const ownership = await AppDataSource.query(
            `SELECT count(DISTINCT shop_id)::int AS total
             FROM public.shop_members
             WHERE user_id = $1
               AND shop_id = ANY($2)
               AND member_type = 'OWNER'
               AND is_active = TRUE
               AND status = 'ACTIVE'`,
            [userId, [34, 35]],
        );
        if (Number(ownership[0]?.total || 0) !== 2) {
            return res.status(403).json({
                success: false,
                message: 'Chỉ chủ sở hữu của cả hai cửa hàng thử nghiệm mới được thực hiện tác vụ này',
            });
        }

        const { seedTestMedia } = await import('../scripts/seed-test-media');
        const result = await seedTestMedia();
        res.json({ success: true, data: result });
    } catch (error: any) {
        console.error('Seed production test media failed:', error);
        res.status(500).json({
            success: false,
            message: error?.message || 'Không thể tạo dữ liệu ảnh kiểm thử',
        });
    }
};

