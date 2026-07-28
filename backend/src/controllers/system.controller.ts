import { Request, Response } from 'express';
import { SystemService } from '../services/system.service';
import { CURRENT_TAX_POLICY } from '../tax/tax-policy';

const systemService = new SystemService();

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

