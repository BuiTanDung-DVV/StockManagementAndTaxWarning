import { Request, Response } from 'express';
import { SalesService } from '../services/sales.service';

const salesService = new SalesService();

const validationMessage = (e: any) => String(e?.message || '');
const isValidation = (message: string) =>
    message.startsWith('Validation:') ||
    message === 'Cannot return a cancelled order' ||
    message.includes('han muc tin dung') ||
    message.includes('háº¡n má»©c tÃ­n dá»¥ng');

const sendServiceError = (res: Response, e: any) => {
    const message = validationMessage(e);
    if (isValidation(message)) {
        res.status(400).json({ success: false, message: message.replace('Validation: ', '') });
        return;
    }
    res.status(500).json({ success: false, message });
};

export const findAll = async (req: Request, res: Response) => {
    try { 
        const customerId = req.query.customerId ? +req.query.customerId : undefined;
        res.json({ success: true, data: await salesService.findAll((req as any).shopId, +(req.query.page || 1), +(req.query.limit || 20), customerId) }); 
    }
    catch (e: any) { sendServiceError(res, e); }
};

export const summary = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await salesService.summary((req as any).shopId, req.query.from as string, req.query.to as string) }); }
    catch (e: any) { sendServiceError(res, e); }
};

export const findOne = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await salesService.findById((req as any).shopId, +req.params.id) }); }
    catch (e: any) {
        if (e.message === 'Order not found') res.status(404).json({ success: false, message: e.message });
        else sendServiceError(res, e);
    }
};

export const create = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await salesService.create((req as any).shopId, req.body) }); }
    catch (e: any) { sendServiceError(res, e); }
};

export const cancel = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await salesService.cancel((req as any).shopId, +req.params.id) }); }
    catch (e: any) { sendServiceError(res, e); }
};

export const updateOrder = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await salesService.updateOrder((req as any).shopId, +req.params.id, req.body) }); }
    catch (e: any) {
        if (e.message === 'Order not found') res.status(404).json({ success: false, message: e.message });
        else sendServiceError(res, e);
    }
};

export const addPayment = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await salesService.addPayment((req as any).shopId, +req.params.id, req.body) }); }
    catch (e: any) { sendServiceError(res, e); }
};

export const createReturn = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await salesService.createReturn((req as any).shopId, +req.params.id, req.body) }); }
    catch (e: any) { sendServiceError(res, e); }
};
