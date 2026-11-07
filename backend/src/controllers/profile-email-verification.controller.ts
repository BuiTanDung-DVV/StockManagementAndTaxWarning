import { Request, Response } from 'express';
import { ZodError } from 'zod';
import { AuthError } from '../auth/auth.errors';
import { confirmProfileEmailVerificationSchema, requestProfileEmailVerificationSchema, requestProfileEmailChangeSchema, confirmProfileEmailChangeSchema } from '../auth/auth.schemas';
import { ProfileEmailVerificationService } from '../services/profile-email-verification.service';
import { ProfileEmailChangeService } from '../services/profile-email-change.service';

const service = new ProfileEmailVerificationService();
const changeService = new ProfileEmailChangeService();

function actor(req: Request) {
    const identity = (req as Request & { user?: { sub?: unknown; ver?: unknown } }).user;
    return { id: Number(identity?.sub), authVersion: Number(identity?.ver) };
}

function errorResponse(error: unknown, res: Response) {
    if (error instanceof ZodError) {
        return res.status(400).json({ success: false, message: error.issues[0]?.message || 'Thông tin không hợp lệ', code: 'VALIDATION_ERROR' });
    }
    if (error instanceof AuthError) {
        return res.status(error.statusCode).json({ success: false, message: error.message, code: error.code });
    }
    if ((error as {code?: unknown})?.code === '23505') {
        return res.status(409).json({ success: false, message: 'Gmail hoặc tên đăng nhập đã được sử dụng', code: 'EMAIL_EXISTS' });
    }
    return res.status(500).json({ success: false, message: 'Không thể cập nhật Gmail. Vui lòng thử lại sau' });
}

export async function requestProfileEmailVerification(req: Request, res: Response) {
    try {
        const dto = requestProfileEmailVerificationSchema.parse(req.body);
        const data = await service.request(actor(req), dto.currentPassword, dto.expectedEmail);
        return res.json({ success: true, data });
    } catch (error) { return errorResponse(error, res); }
}

export async function confirmProfileEmailVerification(req: Request, res: Response) {
    try {
        const dto = confirmProfileEmailVerificationSchema.parse(req.body);
        const data = await service.confirm(actor(req), dto.otpCode, dto.expectedEmail);
        return res.json({ success: true, data });
    } catch (error) { return errorResponse(error, res); }
}

export async function requestProfileEmailChange(req: Request, res: Response) {
    try {
        const dto = requestProfileEmailChangeSchema.parse(req.body);
        return res.json({success:true,data:await changeService.request(actor(req),dto)});
    } catch (error) { return errorResponse(error,res); }
}

export async function confirmProfileEmailChange(req: Request, res: Response) {
    try {
        const dto = confirmProfileEmailChangeSchema.parse(req.body);
        return res.json({success:true,data:await changeService.confirm(actor(req),dto)});
    } catch (error) { return errorResponse(error,res); }
}
