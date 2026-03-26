import { Request, Response } from 'express';
import { NotificationService } from '../services/notification.service';
import { AuthRequest } from '../middleware/auth.middleware';

const svc = new NotificationService();

export const listNotifications = async (req: AuthRequest, res: Response) => {
    try {
        const userId = req.user?.sub;
        const page = +(req.query.page || 1);
        const limit = +(req.query.limit || 20);
        res.json({ success: true, data: await svc.findAll(userId, page, limit) });
    }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const getUnreadCount = async (req: AuthRequest, res: Response) => {
    try {
        const userId = req.user?.sub;
        res.json({ success: true, data: { count: await svc.unreadCount(userId) } });
    }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const markRead = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await svc.markRead(+req.params.id) }); }
    catch (e: any) { res.status(400).json({ success: false, message: e.message }); }
};

export const markAllRead = async (req: AuthRequest, res: Response) => {
    try {
        const userId = req.user?.sub;
        res.json({ success: true, data: await svc.markAllRead(userId) });
    }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
