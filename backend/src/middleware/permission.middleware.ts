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
            if (!userId) {
                return res.status(401).json({
                    success: false,
                    message: 'Unauthorized',
                });
            }

            if (!req.isAllShops && !req.shopId) {
                return res.status(400).json({ success: false, message: 'Thiếu thông tin cửa hàng (shopId)' });
            }

            const memberRepo = AppDataSource.getRepository(ShopMember);
            const keys = Array.isArray(key) ? key : [key];
            
            if (req.isAllShops) {
                if (!options.allowAllShops || level !== 'view') {
                    return res.status(403).json({
                        success: false,
                        message: 'Chức năng này yêu cầu chọn một cửa hàng cụ thể',
                    });
                }

                const members = await memberRepo.find({
                    where: {
                        userId,
                        isActive: true,
                        status: 'ACTIVE',
                    },
                    relations: ['role'],
                });
                const authenticatedShopIds = new Set(req.shopIds || []);
                const allowedMembers = members.filter(
                    (member) =>
                        authenticatedShopIds.has(member.shopId) &&
                        membershipHasAnyPermission(
                            member,
                            keys,
                            level,
                            member.shopId,
                        ),
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

            const shopId = req.shopId!;
            const member = await memberRepo.findOne({
                where: {
                    userId,
                    shopId,
                    isActive: true,
                    status: 'ACTIVE',
                },
                relations: ['role'],
            });

            if (!member) {
                return res.status(403).json({ success: false, message: 'Bạn không thuộc cửa hàng này' });
            }

            req.isOwner = member.memberType === 'OWNER';
            req.memberType = member.memberType;

            // Owners have full access
            if (member.memberType === 'OWNER') return next();

            if (!membershipHasAnyPermission(member, keys, level, shopId)) {
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
        const shopId = req.shopId;

        if (req.isAllShops) {
            return res.status(403).json({
                success: false,
                message: 'Chức năng này yêu cầu chọn một cửa hàng cụ thể',
            });
        }
        if (!shopId) {
            return res.status(400).json({ success: false, message: 'Thiếu thông tin cửa hàng' });
        }

        const memberRepo = AppDataSource.getRepository(ShopMember);
        const member = await memberRepo.findOne({
            where: {
                userId,
                shopId,
                isActive: true,
                status: 'ACTIVE',
            }
        });

        if (!member || member.memberType !== 'OWNER') {
            return res.status(403).json({ success: false, message: 'Chức năng này chỉ dành cho Chủ cửa hàng' });
        }

        next();
    } catch {
        res.status(500).json({ success: false, message: 'Lỗi kiểm tra quyền chủ cửa hàng' });
    }
};
