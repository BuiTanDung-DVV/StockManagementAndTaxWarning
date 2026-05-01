import { Request, Response } from 'express';
import { SupplierService } from '../services/supplier.service';

const supplierService = new SupplierService();

export const findAll = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await supplierService.findAll((req as any).shopId, +(req.query.page || 1), +(req.query.limit || 20), req.query.search as string) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const findOne = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await supplierService.findById((req as any).shopId, +req.params.id) }); }
    catch (e: any) { res.status(e.message === 'Supplier not found' ? 404 : 500).json({ success: false, message: e.message }); }
};

export const create = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await supplierService.create((req as any).shopId, req.body) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const update = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await supplierService.update((req as any).shopId, +req.params.id, req.body) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const remove = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await supplierService.remove((req as any).shopId, +req.params.id) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const payables = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await supplierService.getPayables((req as any).shopId, +req.params.id) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
