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
export const requirePermission = (key: string | string[], level: 'view' | 'edit' | 'full' = 'view') => {
    return async (req: AuthRequest, res: Response, next: NextFunction) => {
        try {
            const userId = req.user?.sub;
            const headerShopId = req.headers['x-shop-id'];
            const queryShopId = req.query.shopId;
            const rawShopId = headerShopId || queryShopId;

            if (!rawShopId) {
                return res.status(400).json({ success: false, message: 'Thiếu thông tin cửa hàng (shopId)' });
            }

            const memberRepo = AppDataSource.getRepository(ShopMember);
            
            if (rawShopId === 'all') {
                // For 'all' shops, verify user is owner of at least one shop
                const members = await memberRepo.find({ where: { userId, isActive: true } });
                if (!members.length) return res.status(403).json({ success: false, message: 'Bạn không thuộc cửa hàng nào' });
                req.isOwner = members.some(m => m.memberType === 'OWNER');
                req.memberType = req.isOwner ? 'OWNER' : 'EMPLOYEE';
                return next();
            }

            const shopId = +(rawShopId);
            const member = await memberRepo.findOne({
                where: { userId, shopId, isActive: true },
                relations: ['role'],
            });

            if (!member) {
                return res.status(403).json({ success: false, message: 'Bạn không thuộc cửa hàng này' });
            }

            req.isOwner = member.memberType === 'OWNER';
            req.memberType = member.memberType;

            // Owners have full access
            if (member.memberType === 'OWNER') return next();

            // Parse permissions from role
            let permissions: Record<string, string> = {};
            if (member.role?.permissions) {
                try { permissions = JSON.parse(member.role.permissions); } catch {}
            }

            const keys = Array.isArray(key) ? key : [key];
            const hasAny = keys.some(k => {
                const userLevel = permissions[k];
                if (!userLevel || userLevel === 'none') return false;
                const hierarchy = ['none', 'view', 'edit', 'full'];
                const userIdx = hierarchy.indexOf(userLevel);
                const requiredIdx = hierarchy.indexOf(level);
                return userIdx >= requiredIdx;
            });

            if (!hasAny) {
                return res.status(403).json({ success: false, message: 'Bạn không có quyền truy cập chức năng này' });
            }

            next();
        } catch {
            res.status(500).json({ success: false, message: 'Lỗi kiểm tra quyền' });
        }
    };
};

/**
 * Middleware: Strictly requires the authenticated user to be the OWNER of the shop.
 */
export const requireOwner = async (req: AuthRequest, res: Response, next: NextFunction) => {
    try {
        const userId = req.user?.sub;
        const shopId = req.shopId || req.query.shopId || req.headers['x-shop-id'];

        if (!shopId) {
            return res.status(400).json({ success: false, message: 'Thiếu thông tin cửa hàng' });
        }

        const memberRepo = AppDataSource.getRepository(ShopMember);
        const member = await memberRepo.findOne({
            where: { userId, shopId: +shopId, isActive: true }
        });

        if (!member || member.memberType !== 'OWNER') {
            return res.status(403).json({ success: false, message: 'Chức năng này chỉ dành cho Chủ cửa hàng' });
        }

        next();
    } catch {
        res.status(500).json({ success: false, message: 'Lỗi kiểm tra quyền chủ cửa hàng' });
    }
};
