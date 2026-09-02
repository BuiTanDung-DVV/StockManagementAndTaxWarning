import { Request, Response } from 'express';
import { ShippingCarrierInputError, ShippingCarrierService } from '../services/shipping-carrier.service';

const service = new ShippingCarrierService();

function fail(res: Response, error: any) {
    const notFound = error?.message === 'Shipping carrier not found';
    const validation = error instanceof ShippingCarrierInputError;
    return res.status(notFound ? 404 : validation ? 400 : 500).json({
        success: false,
        message: notFound ? 'Không tìm thấy đơn vị vận chuyển' : error?.message || 'Không thể xử lý đơn vị vận chuyển',
    });
}

export const list = async (req: Request, res: Response) => {
    try { return res.json({ success: true, data: await service.list((req as any).shopId, req.query.includeInactive === 'true') }); }
    catch (error) { return fail(res, error); }
};
export const create = async (req: Request, res: Response) => {
    try { return res.status(201).json({ success: true, data: await service.create((req as any).shopId, req.body) }); }
    catch (error) { return fail(res, error); }
};
export const update = async (req: Request, res: Response) => {
    try { return res.json({ success: true, data: await service.update((req as any).shopId, Number(req.params.id), req.body) }); }
    catch (error) { return fail(res, error); }
};
export const deactivate = async (req: Request, res: Response) => {
    try { return res.json({ success: true, data: await service.deactivate((req as any).shopId, Number(req.params.id)) }); }
    catch (error) { return fail(res, error); }
};
