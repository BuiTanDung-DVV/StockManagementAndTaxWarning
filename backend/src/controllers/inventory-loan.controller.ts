import { NextFunction, Response } from 'express';
import { AuthRequest } from '../middleware/auth.middleware';
import {
    InventoryLoanError, listInventoryLoans, receiveInventoryLoan,
    requestInventoryLoan, shipInventoryLoan,
} from '../services/inventory-loan.service';

const positiveInteger = (value: unknown): value is number =>
    typeof value === 'number' && Number.isInteger(value) && value > 0 && value <= 2147483647;
const validOperation = (value: unknown): value is string =>
    typeof value === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);

export async function ship(req: AuthRequest, res: Response, next: NextFunction) {
    const id = Number(req.params.id);
    const { quantity, operationId, warehouseId, lenderProductId } = req.body ?? {};
    if (!positiveInteger(id) || !positiveInteger(quantity) || !positiveInteger(warehouseId)
        || !validOperation(operationId) || (lenderProductId !== undefined && !positiveInteger(lenderProductId))) {
        return res.status(400).json({ success: false, message: 'Thông tin xuất hàng không hợp lệ.' });
    }
    try {
        const data = await shipInventoryLoan(req.shopId!, req.user!.sub, id, {
            quantity, operationId, warehouseId, lenderProductId,
        });
        return res.json({ success: true, data });
    } catch (error) {
        if (error instanceof InventoryLoanError) {
            return res.status(409).json({ success: false, message: error.message });
        }
        return next(error);
    }
}

export async function receive(req: AuthRequest, res: Response, next: NextFunction) {
    const id = Number(req.params.id);
    const { quantity, operationId } = req.body ?? {};
    if (!positiveInteger(id) || !positiveInteger(quantity) || !validOperation(operationId)) {
        return res.status(400).json({ success: false, message: 'Thông tin nhận hàng không hợp lệ.' });
    }
    try {
        const data = await receiveInventoryLoan(req.shopId!, req.user!.sub, id, { quantity, operationId });
        return res.json({ success: true, data });
    } catch (error) {
        if (error instanceof InventoryLoanError) {
            return res.status(409).json({ success: false, message: error.message });
        }
        return next(error);
    }
}

export async function list(req: AuthRequest, res: Response, next: NextFunction) {
    try {
        res.json({ success: true, data: await listInventoryLoans(req.shopId!) });
    } catch (error) {
        next(error);
    }
}

export async function request(req: AuthRequest, res: Response, next: NextFunction) {
    const { partnershipId, warehouseId, productId, quantity } = req.body ?? {};
    if (![partnershipId, warehouseId, productId, quantity]
        .every(value => Number.isInteger(value) && value > 0 && value <= 2147483647)) {
        return res.status(400).json({ success: false, message: 'Thông tin phiếu mượn không hợp lệ.' });
    }
    try {
        const data = await requestInventoryLoan(req.shopId!, req.user!.sub, {
            partnershipId, warehouseId, productId, quantity,
        });
        if (!data) {
            return res.status(404).json({ success: false, message: 'Không tìm thấy liên kết đang hoạt động, kho hoặc sản phẩm phù hợp.' });
        }
        return res.status(201).json({ success: true, data });
    } catch (error) {
        return next(error);
    }
}
