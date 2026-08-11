import { Request, Response } from 'express';
import { CustomerService } from '../services/customer.service';
import {
    ImageStorageError,
    ImageStorageService,
} from '../services/image-storage.service';

const customerService = new CustomerService();
const imageStorageService = new ImageStorageService();

const evidenceStorageError = (res: Response, error: unknown) => {
    if (error instanceof ImageStorageError) {
        return res.status(error.statusCode).json({
            success: false,
            message: error.message,
        });
    }
    console.error('Debt evidence image storage error:', error);
    return res.status(500).json({
        success: false,
        message: 'Không thể xử lý ảnh chứng từ công nợ',
    });
};

export const createDebtEvidenceImageUpload = async (
    req: Request,
    res: Response,
) => {
    try {
        const data = await imageStorageService.createDebtEvidenceImageUpload(
            (req as any).shopId,
            req.body,
        );
        return res.json({ success: true, data });
    } catch (error) {
        return evidenceStorageError(res, error);
    }
};

export const confirmDebtEvidenceImageUpload = async (
    req: Request,
    res: Response,
) => {
    try {
        const data = await imageStorageService.confirmDebtEvidenceImage(
            (req as any).shopId,
            String(req.body.objectKey || ''),
        );
        return res.json({ success: true, data });
    } catch (error) {
        return evidenceStorageError(res, error);
    }
};

export const deleteDebtEvidenceImageUpload = async (
    req: Request,
    res: Response,
) => {
    try {
        const data = await imageStorageService.deleteDebtEvidenceImage(
            (req as any).shopId,
            String(req.body.objectKey || ''),
        );
        return res.json({ success: true, data });
    } catch (error) {
        return evidenceStorageError(res, error);
    }
};

export const findAll = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await customerService.findAll((req as any).shopId, +(req.query.page || 1), +(req.query.limit || 20), req.query.search as string) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const findOne = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await customerService.findById((req as any).shopId, +req.params.id) }); }
    catch (e: any) { res.status(e.message === 'Customer not found' ? 404 : 500).json({ success: false, message: e.message }); }
};

export const create = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await customerService.create((req as any).shopId, req.body) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const update = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await customerService.update((req as any).shopId, +req.params.id, req.body) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const remove = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await customerService.remove((req as any).shopId, +req.params.id) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const receivables = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await customerService.getReceivables((req as any).shopId, +req.params.id) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const openReceivables = async (req: Request, res: Response) => {
    try {
        res.json({
            success: true,
            data: await customerService.getOpenReceivables(
                (req as any).shopId,
            ),
        });
    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
};

export const createReceivable = async (req: Request, res: Response) => {
    try {
        res.json({
            success: true,
            data: await customerService.createReceivable(
                (req as any).shopId,
                +req.params.id,
                req.body,
            ),
        });
    }
    catch (e: any) {
        const validation = String(e.message || '').startsWith('Validation:');
        res.status(e.message === 'Customer not found' ? 404 : validation ? 400 : 500)
            .json({ success: false, message: e.message });
    }
};

export const overdueDebts = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await customerService.getOverdueDebts((req as any).shopId) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const debtAging = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await customerService.getDebtAging((req as any).shopId, req.query.asOf as string) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const getDebtEvidence = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await customerService.getDebtEvidence((req as any).shopId, +req.params.id) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const addEvidence = async (req: Request, res: Response) => {
    try {
        res.json({
            success: true,
            data: await customerService.addDebtEvidence(
                (req as any).shopId,
                +req.params.receivableId,
                (req as any).user?.sub,
                req.body,
            ),
        });
    }
    catch (e: any) {
        const validation = String(e.message || '').startsWith('Validation:');
        res.status(e.message === 'Receivable not found' ? 404 : validation ? 400 : 500)
            .json({ success: false, message: e.message });
    }
};

export const removeEvidence = async (req: Request, res: Response) => {
    try {
        res.json({
            success: true,
            data: await customerService.removeDebtEvidence(
                (req as any).shopId,
                +req.params.evidenceId,
            ),
        });
    } catch (e: any) {
        res.status(e.message === 'Debt evidence not found' ? 404 : 500)
            .json({ success: false, message: e.message });
    }
};
