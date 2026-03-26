import { Request, Response } from 'express';
import { CustomerService } from '../services/customer.service';

const customerService = new CustomerService();

export const findAll = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await customerService.findAll(+(req.query.page || 1), +(req.query.limit || 20), req.query.search as string) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const findOne = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await customerService.findById(+req.params.id) }); }
    catch (e: any) { res.status(e.message === 'Customer not found' ? 404 : 500).json({ success: false, message: e.message }); }
};

export const create = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await customerService.create(req.body) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const update = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await customerService.update(+req.params.id, req.body) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const remove = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await customerService.remove(+req.params.id) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const receivables = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await customerService.getReceivables(+req.params.id) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const createReceivable = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: {} }); } // Stub
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const overdueDebts = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await customerService.getOverdueDebts() }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const debtAging = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await customerService.getDebtAging() }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const getDebtEvidence = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await customerService.getDebtEvidence(+req.params.id) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const addEvidence = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: {} }); } // Stub
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const addPayment = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await customerService.addPayment(+req.params.id, +req.params.receivableId, req.body) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
