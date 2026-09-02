import { Request, Response } from 'express';
import { ImageStorageError } from '../services/image-storage.service';
import { InvoiceOcrError, InvoiceOcrService } from '../services/invoice-ocr.service';

const service = new InvoiceOcrService();
const fail = (res: Response, error: any) => res.status(error instanceof ImageStorageError || error instanceof InvoiceOcrError ? error.statusCode : 500).json({ success: false, message: error?.message || 'Không thể xử lý ảnh hóa đơn' });
export const upload = async (req: Request, res: Response) => {
    try {
        const bytes = Buffer.isBuffer(req.body) ? req.body : Buffer.alloc(0);
        const data = await service.uploadAndProcess((req as any).shopId, Number((req as any).user?.sub), { fileName: String(req.headers['x-file-name'] || 'invoice'), contentType: String(req.headers['content-type'] || '').split(';')[0], size: bytes.length }, bytes);
        return res.status(201).json({ success: true, data });
    } catch (error) { return fail(res, error); }
};
export const get = async (req: Request, res: Response) => { try { return res.json({ success: true, data: await service.get((req as any).shopId, Number(req.params.id)) }); } catch (error) { return fail(res, error); } };
export const retry = async (req: Request, res: Response) => { try { return res.json({ success: true, data: await service.retry((req as any).shopId, Number(req.params.id)) }); } catch (error) { return fail(res, error); } };
export const confirm = async (req: Request, res: Response) => { try { return res.json({ success: true, data: await service.confirm((req as any).shopId, Number(req.params.id), Number((req as any).user?.sub), req.body) }); } catch (error) { return fail(res, error); } };
