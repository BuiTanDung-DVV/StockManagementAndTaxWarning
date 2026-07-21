import { Request, Response } from 'express';
import { SystemService } from '../services/system.service';

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

export const getInvoices = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await systemService.getInvoices((req as any).shopId, +(req.query.page || 1), +(req.query.limit || 20)) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const getInvoiceById = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: {} }); } // Stub
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const getInvoiceSummary = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: {} }); } // Stub
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const createInvoice = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: {} }); } // Stub
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const scanInvoice = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await systemService.scanInvoice((req as any).shopId, req.body) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const getInvoiceScans = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: [] }); } // Stub
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const createInvoiceScan = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: {} }); } // Stub
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const updateInvoiceScan = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: {} }); } // Stub
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const getPurchasesWithoutInvoice = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await systemService.getPurchaseWithoutInvoice((req as any).shopId, +(req.query.page || 1), +(req.query.limit || 20)) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const createPurchaseWithoutInvoice = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: {} }); } // Stub
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const getConfigs = async (req: Request, res: Response) => {
    try {
        const shopId = (req as any).shopId;
        const taxExemptionThreshold = await systemService.getSystemConfig(shopId, 'TAX_EXEMPTION_THRESHOLD', '100000000');
        const cashPurchaseLimit = await systemService.getSystemConfig(shopId, 'CASH_PURCHASE_LIMIT', '20000000');
        const warningRevenueThreshold = await systemService.getSystemConfig(shopId, 'WARNING_REVENUE_THRESHOLD', '90000000');
        
        res.json({
            success: true,
            data: {
                taxExemptionThreshold: Number(taxExemptionThreshold),
                cashPurchaseLimit: Number(cashPurchaseLimit),
                warningRevenueThreshold: Number(warningRevenueThreshold)
            }
        });
    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
};

export const saveConfigs = async (req: Request, res: Response) => {
    try {
        const shopId = (req as any).shopId;
        const { taxExemptionThreshold, cashPurchaseLimit, warningRevenueThreshold } = req.body;
        
        if (taxExemptionThreshold !== undefined) {
            await systemService.setSystemConfig(shopId, 'TAX_EXEMPTION_THRESHOLD', String(taxExemptionThreshold));
        }
        if (cashPurchaseLimit !== undefined) {
            await systemService.setSystemConfig(shopId, 'CASH_PURCHASE_LIMIT', String(cashPurchaseLimit));
        }
        if (warningRevenueThreshold !== undefined) {
            await systemService.setSystemConfig(shopId, 'WARNING_REVENUE_THRESHOLD', String(warningRevenueThreshold));
        }
        
        res.json({ success: true, message: 'Cập nhật cấu hình hệ thống thành công' });
    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
};

