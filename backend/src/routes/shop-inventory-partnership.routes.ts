import { NextFunction, Response, Router } from 'express';
import { AppDataSource } from '../config/db.config';
import { authenticateJwt, AuthRequest } from '../middleware/auth.middleware';
import { requireOwner } from '../middleware/permission.middleware';

const router = Router();
const path = '/inventory/partner-shops';

router.use(path, authenticateJwt, requireOwner);

router.get(path, async (req: AuthRequest, res: Response, next: NextFunction) => {
    try {
        const data = await AppDataSource.query(
            `SELECT p.id, p.status, p.created_at AS "createdAt",
                    (p.requester_shop_id = $1) AS "outgoing",
                    other.id AS "partnerShopId", other.shop_name AS "partnerName"
             FROM shop_inventory_partnerships p
             JOIN shop_profiles other ON other.id = CASE WHEN p.requester_shop_id = $1
                  THEN p.recipient_shop_id ELSE p.requester_shop_id END
             WHERE $1 IN (p.requester_shop_id, p.recipient_shop_id)
             ORDER BY p.id DESC`,
            [req.shopId],
        );
        res.json({ success: true, data });
    } catch (error) {
        next(error);
    }
});

router.post(path, async (req: AuthRequest, res: Response, next: NextFunction) => {
    const code = typeof req.body?.shopCode === 'string' ? req.body.shopCode.trim().toUpperCase() : '';
    if (!/^[A-Z0-9]{4,20}$/.test(code)) {
        return res.status(400).json({
            success: false, message: 'Nhập mã cửa hàng từ 4 đến 20 ký tự, chỉ gồm chữ và số.',
        });
    }

    try {
        const [partner] = await AppDataSource.query(
            'SELECT id FROM shop_profiles WHERE shop_code = $1 AND id <> $2',
            [code, req.shopId],
        );
        if (!partner) {
            return res.status(404).json({ success: false, message: 'Không tìm thấy cửa hàng đối tác phù hợp.' });
        }
        const [invite] = await AppDataSource.query(
            `INSERT INTO shop_inventory_partnerships (requester_shop_id, recipient_shop_id, requested_by)
             VALUES ($1, $2, $3)
             ON CONFLICT DO NOTHING
             RETURNING id, status`,
            [req.shopId, partner.id, req.user?.sub],
        );
        if (!invite) {
            return res.status(409).json({ success: false, message: 'Hai cửa hàng đã có lời mời hoặc liên kết đang hoạt động.' });
        }
        return res.status(201).json({ success: true, data: invite });
    } catch (error) {
        return next(error);
    }
});

router.put(path + '/:id', async (req: AuthRequest, res: Response, next: NextFunction) => {
    const id = Number(req.params.id);
    const status = req.body?.status;
    if (!Number.isInteger(id) || id < 1 || id > 2147483647
        || !['ACTIVE', 'REJECTED', 'CLOSED'].includes(status)) {
        return res.status(400).json({ success: false, message: 'Lời mời hoặc trạng thái không hợp lệ.' });
    }

    try {
        const [partnership] = await AppDataSource.query(
            `WITH changed AS (
                UPDATE shop_inventory_partnerships
                SET status = $2, resolved_by = $3, resolved_at = NOW()
                WHERE id = $1 AND (
                    (status = 'PENDING' AND recipient_shop_id = $4 AND $2 IN ('ACTIVE', 'REJECTED'))
                    OR (status = 'ACTIVE' AND $2 = 'CLOSED' AND $4 IN (requester_shop_id, recipient_shop_id))
                )
                RETURNING id, status
            ) SELECT id, status FROM changed`,
            [id, status, req.user?.sub, req.shopId],
        );
        if (!partnership) {
            return res.status(404).json({ success: false, message: 'Không tìm thấy liên kết có thể cập nhật.' });
        }
        return res.json({ success: true, data: partnership });
    } catch (error) {
        return next(error);
    }
});

export default router;
