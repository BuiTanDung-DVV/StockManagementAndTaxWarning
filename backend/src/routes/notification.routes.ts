import { Router } from 'express';
import { authenticateJwt } from '../middleware/auth.middleware';
import * as ctrl from '../controllers/notification.controller';

const router = Router();

router.get('/notifications', authenticateJwt, ctrl.listNotifications);
router.get('/notifications/unread-count', authenticateJwt, ctrl.getUnreadCount);
router.put('/notifications/:id/read', authenticateJwt, ctrl.markRead);
router.put('/notifications/read-all', authenticateJwt, ctrl.markAllRead);

export default router;
