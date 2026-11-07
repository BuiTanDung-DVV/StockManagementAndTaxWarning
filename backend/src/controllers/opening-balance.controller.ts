import { Response } from 'express';
import { AppDataSource } from '../config/db.config';
import { AuthRequest } from '../middleware/auth.middleware';
import { OpeningBalancePlanError } from '../finance/opening-balance-plan.utils';
import { OpeningBalanceService, OpeningBalanceServiceError } from '../finance/opening-balance.service';

const service = new OpeningBalanceService(AppDataSource);

function body(req: AuthRequest, allowed: string[]) {
    const value = req.body;
    if (!value || typeof value !== 'object' || Array.isArray(value)
        || Object.keys(value).some(key => !allowed.includes(key))) {
        throw new OpeningBalanceServiceError('INVALID_INPUT', 'Dữ liệu yêu cầu không hợp lệ.');
    }
    // Shop scope always comes from authenticated middleware, never the request body.
    return { ...value, shopId: Number(req.shopId) };
}

function actor(req: AuthRequest) {
    return { id: Number(req.user?.sub), authVersion: Number(req.user?.ver) };
}

function fail(res: Response, error: unknown) {
    if (error instanceof OpeningBalanceServiceError) {
        return res.status(error.status).json({ success: false, message: error.message,
            code: error.code, blockers: error.blockers });
    }
    if (error instanceof OpeningBalancePlanError) {
        return res.status(400).json({ success: false, code: 'INVALID_INPUT', message: error.message });
    }
    console.error('Opening balance failed', { code: (error as { code?: string })?.code });
    return res.status(500).json({ success: false, code: 'RESULT_UNKNOWN',
        message: 'Chưa xác nhận được kết quả. Hãy tra lại cùng mã lượt ghi trước khi thử lại.' });
}

export async function snapshotOpeningBalance(req: AuthRequest, res: Response) {
    try {
        const input = body(req, ['asOf', 'keys', 'sourceLinks']);
        const data = await service.snapshot(actor(req), input);
        return res.json({ success: true, data });
    } catch (error) { return fail(res, error); }
}

export async function previewOpeningBalance(req: AuthRequest, res: Response) {
    try {
        const input = body(req, ['asOf', 'expectedRevision', 'rows', 'sourceLinks']);
        const data = await service.preview(actor(req), input);
        return res.json({ success: true, data });
    } catch (error) { return fail(res, error); }
}

export async function commitOpeningBalance(req: AuthRequest, res: Response) {
    try {
        const input = body(req, ['asOf', 'expectedRevision', 'rows', 'sourceLinks', 'operationId', 'expectedPlanHash']);
        const data = await service.commit(actor(req), input);
        return res.json({ success: true, data });
    } catch (error) { return fail(res, error); }
}

export async function openingBalanceStatus(req: AuthRequest, res: Response) {
    try {
        const data = await service.status(actor(req), Number(req.shopId), String(req.params.operationId));
        return res.json({ success: true, data });
    } catch (error) { return fail(res, error); }
}

export async function openingBalanceHistory(req: AuthRequest, res: Response) {
    try {
        const value = req.query.beforeId;
        if (Object.keys(req.query).some(key => !['beforeId', 'shopId'].includes(key))
            || (value !== undefined && (typeof value !== 'string' || !/^[1-9]\d*$/.test(value)))) {
            throw new OpeningBalanceServiceError('INVALID_CURSOR', 'Mốc lịch sử không hợp lệ.');
        }
        const data = await service.history(actor(req), Number(req.shopId), value === undefined ? undefined : Number(value));
        return res.json({ success: true, data });
    } catch (error) { return fail(res, error); }
}
