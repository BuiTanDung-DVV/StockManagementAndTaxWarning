import { NextFunction, Response } from 'express';
import { AuthRequest } from '../middleware/auth.middleware';
import { listInventoryShelves, saveInventoryShelf } from '../services/inventory-shelf.service';

export async function list(req: AuthRequest, res: Response, next: NextFunction) {
    try {
        res.json({ success: true, data: await listInventoryShelves(req.shopId!) });
    } catch (error) {
        next(error);
    }
}

export async function save(req: AuthRequest, res: Response, next: NextFunction) {
    const { warehouseId, productId, level, bin } = req.body ?? {};
    const rack = typeof req.body?.rack === 'string' ? req.body.rack.trim() : '';
    if (![warehouseId, productId, level, bin].every(value => Number.isInteger(value) && value > 0)
        || warehouseId > 2147483647 || productId > 2147483647
        || level > 12 || bin > 16 || !rack || rack.length > 24) {
        return res.status(400).json({ success: false, message: 'Vị trí kệ không hợp lệ.' });
    }

    try {
        const data = await saveInventoryShelf(req.shopId!, { warehouseId, productId, rack, level, bin });
        if (!data) {
            return res.status(404).json({ success: false, message: 'Không tìm thấy kho hoặc sản phẩm trong cửa hàng.' });
        }
        return res.json({ success: true, data });
    } catch (error) {
        return next(error);
    }
}
