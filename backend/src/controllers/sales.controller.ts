import { SalesWriteError } from '../sales/sales-write-authorization';
import { recordSalesOrderPayment } from './sales-order-payment.controller';
import { AuthRequest } from '../middleware/auth.middleware';
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
    if (e instanceof SalesWriteError) { res.status(e.status).json({ success: false, message: e.message }); return; }
    if (message === 'Order not found') { res.status(404).json({ success: false, message: 'Không tìm thấy đơn hàng' }); return; }
    if (['55P03','40001','40P01','23505'].includes(e?.code)) { res.status(409).json({ success: false, message: 'Dữ liệu đang được xử lý hoặc đã thay đổi. Hãy tải lại đơn để kiểm tra trước khi ghi lại.' }); return; }
    if (isValidation(message)) {
        res.status(400).json({ success: false, message: message.replace('Validation: ', '') });
        return;
    }
    console.error('Sales operation failed', { name: e?.name, code: e?.code });
    res.status(500).json({ success: false, message: 'Chưa thể hoàn tất thao tác đơn hàng. Hãy tải lại để kiểm tra trước khi thử lại.' });
};

export const findAll = async (req: Request, res: Response) => {
    try { 
        const customerId = req.query.customerId ? +req.query.customerId : undefined;
        res.json({
            success: true,
            data: await salesService.findAll(
                (req as any).isAllShops ? (req as any).shopIds : (req as any).shopId,
                +(req.query.page || 1),
                +(req.query.limit || 20),
                customerId,
                req.query.status as string,
                req.query.search as string,
                req.query.from as string,
                req.query.to as string,
            ),
        });
    }
    catch (e: any) {
        const message = validationMessage(e);
        if (message.startsWith('Validation:')) {
            res.status(400).json({
                success: false,
                message: message.replace('Validation: ', ''),
            });
            return;
        }
        console.error('Sales order list query failed:', validationMessage(e));
        res.status(500).json({
            success: false,
            message: 'Không thể tải danh sách đơn hàng. Vui lòng thử lại.',
        });
    }
};

const getShopId = (req: any) => req.isAllShops ? req.shopIds : req.shopId;

export const summary = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await salesService.summary(getShopId(req), req.query.from as string, req.query.to as string) }); }
    catch (e: any) { res.status(400).json({ success: false, message: e.message }); }
};

export const topProducts = async (req: Request, res: Response) => {
    try {
        res.json({
            success: true,
            data: await salesService.getTopProducts(
                getShopId(req),
                req.query.from as string,
                req.query.to as string,
                req.query.previousFrom as string,
                req.query.previousTo as string,
            ),
        });
    }
    catch (e: any) { res.status(400).json({ success: false, message: e.message }); }
};

export const topReturnedProducts = async (req: Request, res: Response) => {
    try {
        res.json({
            success: true,
            data: await salesService.getTopReturnedProducts(
                getShopId(req),
                req.query.from as string,
                req.query.to as string,
            ),
        });
    }
    catch (e: any) { res.status(400).json({ success: false, message: e.message }); }
};

export const paymentSummary = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await salesService.paymentMethodSummary(getShopId(req), req.query.from as string, req.query.to as string) }); }
    catch (e: any) { res.status(400).json({ success: false, message: e.message }); }
};

export const findOne = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await salesService.findById((req as any).shopId, +req.params.id) }); }
    catch (e: any) {
        if (e.message === 'Order not found') res.status(404).json({ success: false, message: e.message });
        else sendServiceError(res, e);
    }
};

export const create = async (req: Request, res: Response) => {
    try { 
        res.json({ success: true, data: await salesService.createForActor((req as any).shopId, req.body, { id: Number((req as any).user?.sub), authVersion: Number((req as any).user?.ver) }) }); 
    }
    catch (e: any) { sendServiceError(res, e); }
};

export const cancel = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await salesService.cancelForActor((req as any).shopId, +req.params.id, { id: Number((req as any).user?.sub), authVersion: Number((req as any).user?.ver) }) }); }
    catch (e: any) { sendServiceError(res, e); }
};

export const updateOrder = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await salesService.updateOrder((req as any).shopId, +req.params.id, req.body) }); }
    catch (e: any) {
        if (e.message === 'Order not found') res.status(404).json({ success: false, message: e.message });
        else sendServiceError(res, e);
    }
};

export const addPayment = (req: Request, res: Response) => recordSalesOrderPayment(req as AuthRequest,res);

export const createReturn = async (req: Request, res: Response) => {
    try { 
        res.json({ success: true, data: await salesService.createReturnForActor((req as any).shopId, +req.params.id, req.body, { id: Number((req as any).user?.sub), authVersion: Number((req as any).user?.ver) }) }); 
    }
    catch (e: any) { sendServiceError(res, e); }
};
