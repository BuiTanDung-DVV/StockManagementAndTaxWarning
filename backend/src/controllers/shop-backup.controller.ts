import { Request, Response } from 'express';
import { ShopBackupError, ShopBackupService } from '../services/shop-backup.service';

const service = new ShopBackupService();
const userId = (req: Request) => Number((req as any).user?.sub);
const password = (req: Request) => req.body?.password ?? req.headers['x-backup-password'];
const fail = (res: Response, error: any) => res.status(error instanceof ShopBackupError ? error.statusCode : 500).json({ success: false, message: error instanceof ShopBackupError ? error.message : 'Không thể xử lý bản sao dữ liệu' });

export const exportBackup = async (req: Request, res: Response) => {
    try {
        const result = await service.export((req as any).shopId, userId(req), password(req));
        res.setHeader('Content-Type', 'application/gzip');
        res.setHeader('Content-Disposition', `attachment; filename="${result.fileName}"`);
        res.setHeader('X-Backup-Checksum', result.manifest.checksum);
        return res.send(result.bytes);
    } catch (error) { return fail(res, error); }
};
export const validateBackup = async (req: Request, res: Response) => {
    try { return res.json({ success: true, data: await service.validate((req as any).shopId, userId(req), password(req), Buffer.isBuffer(req.body) ? req.body : Buffer.alloc(0)) }); }
    catch (error) { return fail(res, error); }
};
export const restoreBackup = async (req: Request, res: Response) => {
    try { return res.json({ success: true, data: await service.restore((req as any).shopId, userId(req), password(req), req.body?.backupId) }); }
    catch (error) { return fail(res, error); }
};
export const rollbackBackup = async (req: Request, res: Response) => {
    try { return res.json({ success: true, data: await service.rollback((req as any).shopId, userId(req), password(req), String(req.params.id)) }); }
    catch (error) { return fail(res, error); }
};
