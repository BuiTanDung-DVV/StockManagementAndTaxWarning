import { Request, Response } from 'express';
import { SystemService } from '../services/system.service';

const systemService = new SystemService();

export const getShopProfile = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await systemService.getShopProfile() }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const saveShopProfile = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await systemService.updateShopProfile(1, req.body) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const getActivityLogs = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await systemService.getActivityLogs(+(req.query.page || 1), +(req.query.limit || 20)) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const getInvoices = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await systemService.getInvoices(+(req.query.page || 1), +(req.query.limit || 20)) }); }
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
    try { res.json({ success: true, data: await systemService.scanInvoice(req.body) }); }
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
    try { res.json({ success: true, data: await systemService.getPurchaseWithoutInvoice(+(req.query.page || 1), +(req.query.limit || 20)) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const createPurchaseWithoutInvoice = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: {} }); } // Stub
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
