import { Router, Request, Response } from 'express';
import { ProfileService } from '../services/profile.service';

const router = Router();
const svc = new ProfileService();

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
        const result = await svc.updateProfile(userId, req.body);
        res.json({ success: true, data: result, message: 'Cập nhật thành công' });
    } catch (e: any) {
        res.status(400).json({ success: false, message: e.message });
    }
});

// PUT /api/profile/password
router.put('/password', async (req: Request, res: Response) => {
    try {
        const userId = (req as any).user?.sub;
        if (!userId) return res.status(401).json({ success: false, message: 'Unauthorized' });
        const result = await svc.changePassword(userId, req.body);
        res.json({ success: true, data: result, message: 'Đổi mật khẩu thành công' });
    } catch (e: any) {
        res.status(400).json({ success: false, message: e.message });
    }
});

export default router;
