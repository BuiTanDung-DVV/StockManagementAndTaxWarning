import { Response, NextFunction } from 'express';
import { AuthRequest } from './auth.middleware';
import { AppDataSource } from '../config/db.config';
import { ShopMember } from '../shop/entities';

/**
 * Middleware factory: checks that the authenticated user has a specific
 * permission (at the given level) for the shop identified by `req.query.shopId`.
 *
 * OWNER members automatically pass all permission checks.
 *
 * Usage: router.get('/products', authenticateJwt, requirePermission('products', 'view'), ctrl.list);
 */
export const requirePermission = (key: string, level: 'view' | 'full' = 'view') => {
    return async (req: AuthRequest, res: Response, next: NextFunction) => {
        try {
            const userId = req.user?.sub;
            const shopId = +(req.query.shopId || 1);

            const memberRepo = AppDataSource.getRepository(ShopMember);
            const member = await memberRepo.findOne({
                where: { userId, shopId, isActive: true },
                relations: ['role'],
            });

            if (!member) {
                return res.status(403).json({ success: false, message: 'Bạn không thuộc cửa hàng này' });
            }

            // Owners have full access
            if (member.memberType === 'OWNER') return next();

            // Parse permissions from role
            let permissions: Record<string, string> = {};
            if (member.role?.permissions) {
                try { permissions = JSON.parse(member.role.permissions); } catch {}
            }

            const userLevel = permissions[key];
            if (!userLevel || userLevel === 'none') {
                return res.status(403).json({ success: false, message: 'Bạn không có quyền truy cập chức năng này' });
            }

            // Check hierarchy: none < view < edit < full
            const hierarchy = ['none', 'view', 'edit', 'full'];
            const userIdx = hierarchy.indexOf(userLevel);
            const requiredIdx = hierarchy.indexOf(level);
            if (userIdx < requiredIdx) {
                return res.status(403).json({ success: false, message: `Bạn chỉ có quyền "${userLevel}", cần quyền "${level}"` });
            }

            next();
        } catch {
            res.status(500).json({ success: false, message: 'Lỗi kiểm tra quyền' });
        }
    };
};
