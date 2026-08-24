import { Request, Response } from 'express';
import { SystemService } from '../services/system.service';
import { ImageStorageError } from '../services/image-storage.service';
import { taxPolicyService } from '../services/tax-policy.service';

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

export const getPaymentBankOptions = async (req: Request, res: Response) => {
    try {
        const data = await systemService.getPaymentBankOptions((req as any).shopId);
        return res.json({ success: true, data });
    } catch (error: any) {
        return res.status(500).json({
            success: false,
            message: error.message || 'Không thể tải danh mục ngân hàng',
        });
    }
};

export const getTaxReferenceData = async (req: Request, res: Response) => {
    try {
        const data = await systemService.getTaxReferenceData((req as any).shopId);
        return res.json({ success: true, data });
    } catch (error: any) {
        return res.status(500).json({
            success: false,
            message: error.message || 'Không thể tải dữ liệu tham chiếu thuế từ DB',
        });
    }
};

export const uploadShopPaymentQrImage = async (req: Request, res: Response) => {
    try {
        const bytes = Buffer.isBuffer(req.body) ? req.body : Buffer.alloc(0);
        const data = await systemService.uploadShopPaymentQrImage(
            (req as any).shopId,
            {
                fileName: String(req.headers['x-file-name'] || 'image'),
                contentType: String(req.headers['content-type'] || '').split(';')[0],
                size: bytes.length,
            },
            bytes,
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
    catch (e: any) {
        const validation = String(e.message || '').startsWith('Validation:');
        res.status(validation ? 400 : 500).json({ success: false, message: e.message });
    }
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
        const [cashPurchaseLimit, policy] = await Promise.all([
            systemService.getSystemConfig(shopId, 'CASH_PURCHASE_LIMIT'),
            taxPolicyService.getCurrentPolicy(),
        ]);
        
        res.json({
            success: true,
            data: {
                taxExemptionThreshold: policy.taxExemptionThreshold,
                cashPurchaseLimit: Number(cashPurchaseLimit),
                warningRevenueThreshold: policy.warningRevenueThreshold,
                taxPolicy: policy,
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

