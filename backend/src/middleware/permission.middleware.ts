import { Response, NextFunction } from 'express';
import { AuthRequest } from './auth.middleware';
import { AppDataSource } from '../config/db.config';
import { ShopMember } from '../shop/entities';
import {
    membershipHasAnyPermission,
    PermissionLevel,
} from './permission.utils';

interface PermissionOptions {
    allowAllShops?: boolean;
}

/**
 * Middleware factory: checks that the authenticated user has a specific
 * permission (at the given level) for the shop identified by `req.query.shopId`.
 *
 * OWNER members automatically pass all permission checks.
 *
 * Usage: router.get('/products', authenticateJwt, requirePermission('products', 'view'), ctrl.list);
 */
export const requirePermission = (
    key: string | string[],
    level: Exclude<PermissionLevel, 'none'> = 'view',
    options: PermissionOptions = {},
) => {
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
            const keys = Array.isArray(key) ? key : [key];
            
            if (rawShopId === 'all') {
                if (!options.allowAllShops || level !== 'view') {
                    return res.status(403).json({
                        success: false,
                        message: 'Chức năng này yêu cầu chọn một cửa hàng cụ thể',
                    });
                }

                const members = await memberRepo.find({
                    where: { userId, isActive: true },
                    relations: ['role'],
                });
                const allowedMembers = members.filter((member) =>
                    membershipHasAnyPermission(member, keys, level),
                );

                if (!allowedMembers.length) {
                    return res.status(403).json({
                        success: false,
                        message: 'Bạn không có quyền truy cập chức năng này',
                    });
                }

                req.isAllShops = true;
                req.shopIds = allowedMembers.map((member) => member.shopId);
                // A single boolean cannot express mixed owner/employee scopes.
                // Stay conservative so downstream queries never broaden access.
                req.isOwner = allowedMembers.every(
                    (member) => member.memberType === 'OWNER',
                );
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

            if (!membershipHasAnyPermission(member, keys, level)) {
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
        if (req.isAllShops || shopId === 'all') {
            return res.status(403).json({
                success: false,
                message: 'Chức năng này yêu cầu chọn một cửa hàng cụ thể',
            });
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
