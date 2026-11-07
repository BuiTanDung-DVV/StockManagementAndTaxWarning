import { Router, Request, Response } from 'express';
import { ProfileService } from '../services/profile.service';
import { AuthError } from '../auth/auth.errors';
import { changePasswordSchema, updateProfileSchema } from '../auth/auth.schemas';
import { otpRateLimit, requireTrustedWebRequest } from '../middleware/auth-rate-limit.middleware';
import { confirmProfileEmailVerification, requestProfileEmailVerification, requestProfileEmailChange, confirmProfileEmailChange } from '../controllers/profile-email-verification.controller';

const router = Router();
const svc = new ProfileService();

// index.ts authenticates the entire /profile router before mounting it.
router.post('/email-verification/request', otpRateLimit, requireTrustedWebRequest, requestProfileEmailVerification);
router.post('/email-verification/confirm', otpRateLimit, requireTrustedWebRequest, confirmProfileEmailVerification);
router.post('/email-change/request', otpRateLimit, requireTrustedWebRequest, requestProfileEmailChange);
router.post('/email-change/confirm', otpRateLimit, requireTrustedWebRequest, confirmProfileEmailChange);

// GET /api/profile
router.get('/', async (req: Request, res: Response) => {
    try {
        const userId = (req as any).user?.sub;
        if (!userId) return res.status(401).json({ success: false, message: 'Unauthorized' });
        const profile = await svc.getProfile(userId);
        res.json({ success: true, data: profile });
    } catch (e: any) {
        res.status(400).json({ success: false, message: e.message });
    }
});

// PUT /api/profile
router.put('/', async (req: Request, res: Response) => {
    try {
        const userId = (req as any).user?.sub;
        if (!userId) return res.status(401).json({ success: false, message: 'Unauthorized' });
        const result = await svc.updateProfile(userId, updateProfileSchema.parse(req.body), Number((req as any).user?.ver));
        res.json({ success: true, data: result, message: 'Cập nhật thành công' });
    } catch (e: any) {
        if (e instanceof AuthError) return res.status(e.statusCode).json({success:false,message:e.message,code:e.code});
        res.status(400).json({ success: false, message: e.message });
    }
});

// PUT /api/profile/password
router.put('/password', async (req: Request, res: Response) => {
    try {
        const userId = (req as any).user?.sub;
        if (!userId) return res.status(401).json({ success: false, message: 'Unauthorized' });
        const result = await svc.changePassword(userId, changePasswordSchema.parse(req.body), Number((req as any).user?.ver));
        res.json({ success: true, data: result, message: 'Đổi mật khẩu thành công' });
    } catch (e: any) {
        if (e instanceof AuthError) return res.status(e.statusCode).json({success:false,message:e.message,code:e.code});
        res.status(400).json({ success: false, message: e.message });
    }
});

export default router;
