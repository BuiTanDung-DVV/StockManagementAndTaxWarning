import { Request, Response } from 'express';
import { SalesService } from '../services/sales.service';

const salesService = new SalesService();

export const findAll = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await salesService.findAll(+(req.query.page || 1), +(req.query.limit || 20)) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const summary = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await salesService.summary(req.query.from as string, req.query.to as string) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const findOne = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await salesService.findById(+req.params.id) }); }
    catch (e: any) {
        if (e.message === 'Order not found') res.status(404).json({ success: false, message: e.message });
        else res.status(500).json({ success: false, message: e.message });
    }
};

export const create = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await salesService.create(req.body) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const cancel = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await salesService.cancel(+req.params.id) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const addPayment = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await salesService.addPayment(+req.params.id, req.body) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const createReturn = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await salesService.createReturn(+req.params.id, req.body) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
