import { Request, Response } from 'express';
import { InventoryService } from '../services/inventory.service';
import { StockTakeInputError } from '../inventory/stock-take-input.utils';
import { PurchaseOrderInputError } from '../inventory/purchase-order-input.utils';
import { InventoryMasterInputError } from '../inventory/inventory-master-input.utils';

const inventoryService = new InventoryService();

const getShopId = (req: any) => req.isAllShops ? req.shopIds : req.shopId;

export const getStock = async (req: Request, res: Response) => {
    try {
        const warehouseId = req.query.warehouseId === undefined
            ? undefined
            : Number(req.query.warehouseId);
        const page = Number(req.query.page || 1);
        const limit = Math.min(Number(req.query.limit || 20), 500);
        if (!Number.isSafeInteger(page) || page <= 0 || !Number.isSafeInteger(limit) || limit <= 0 ||
            (warehouseId !== undefined && (!Number.isSafeInteger(warehouseId) || warehouseId <= 0))) {
            res.status(400).json({ success: false, message: 'Tham số tồn kho không hợp lệ' });
            return;
        }
        if ((req as any).isAllShops && warehouseId !== undefined) {
            res.status(400).json({
                success: false,
                message: 'Bộ lọc kho yêu cầu chọn một cửa hàng cụ thể',
            });
            return;
        }
        if (warehouseId !== undefined) {
            await inventoryService.getWarehouses((req as any).shopId).then((warehouses) => {
                if (!warehouses.some((warehouse) => warehouse.id === warehouseId && warehouse.isActive)) {
                    throw new Error('Warehouse not found for shop');
                }
            });
        }
        res.json({ success: true, data: await inventoryService.getStock(getShopId(req), page, limit, warehouseId) });
    }
    catch (e: any) { res.status(e.message === 'Warehouse not found for shop' ? 400 : 500).json({ success: false, message: e.message }); }
};
export const getLowStock = async (req: Request, res: Response) => {
    try { 
        const threshold = req.query.threshold ? +(req.query.threshold) : undefined;
        res.json({ success: true, data: await inventoryService.getLowStock(getShopId(req), threshold) }); 
    }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const getMovements = async (req: Request, res: Response) => {
    try {
        const page = Number(req.query.page || 1);
        const limit = Math.min(Number(req.query.limit || 20), 100);
        const productId = req.query.productId === undefined ? undefined : Number(req.query.productId);
        if (!Number.isSafeInteger(page) || page <= 0 || !Number.isSafeInteger(limit) || limit <= 0 ||
            (productId !== undefined && (!Number.isSafeInteger(productId) || productId <= 0))) {
            res.status(400).json({ success: false, message: 'Tham số lịch sử kho không hợp lệ' });
            return;
        }
        res.json({
            success: true,
            data: await inventoryService.getMovements((req as any).shopId, page, limit, productId),
        });
    }
    catch (e: any) {
        res.status(String(e.message || '').startsWith('Validation:') ? 400 : 500).json({ success: false, message: e.message });
    }
};

export const getWarehouses = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await inventoryService.getWarehouses((req as any).shopId) }); }
    catch (e: any) { res.status(400).json({ success: false, message: e.message }); }
};

export const createWarehouse = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await inventoryService.createWarehouse((req as any).shopId, req.body) }); }
    catch (e: any) { res.status(e instanceof InventoryMasterInputError ? 400 : 500).json({ success: false, message: e.message }); }
};

export const getCategoriesSummary = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await inventoryService.getCategoriesSummary(getShopId(req)) }); }
    catch (e: any) { res.status(400).json({ success: false, message: e.message }); }
};

export const getAbcAnalysis = async (req: Request, res: Response) => {
    try {
        res.json({
            success: true,
            data: await inventoryService.getAbcAnalysis(
                getShopId(req),
                req.query.from as string,
                req.query.to as string,
            ),
        });
    }
    catch (e: any) { res.status(400).json({ success: false, message: e.message }); }
};

export const getXntReport = async (req: Request, res: Response) => {
    try { 
        const { from, to, warehouseId } = req.query;
        res.json({ 
            success: true, 
            data: await inventoryService.getXntReport(
                (req as any).shopId,
                from as string, 
                to as string, 
                warehouseId ? +(warehouseId) : undefined
            ) 
        }); 
    }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const getExpiringProducts = async (req: Request, res: Response) => {
    try { 
        const daysAhead = req.query.daysAhead ? +(req.query.daysAhead) : 30;
        if (!Number.isSafeInteger(daysAhead) || daysAhead <= 0 || daysAhead > 3650) {
            res.status(400).json({ success: false, message: 'Số ngày cảnh báo hết hạn không hợp lệ' });
            return;
        }
        res.json({ success: true, data: await inventoryService.getExpiringProducts(getShopId(req), daysAhead) });
    }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const getSlowMoving = async (req: Request, res: Response) => {
    try { 
        const daysUnsold = req.query.daysUnsold ? +(req.query.daysUnsold) : 30;
        if (!Number.isSafeInteger(daysUnsold) || daysUnsold <= 0 || daysUnsold > 3650) {
            res.status(400).json({ success: false, message: 'Số ngày chậm luân chuyển không hợp lệ' });
            return;
        }
        res.json({ success: true, data: await inventoryService.getSlowMovingProducts(getShopId(req), daysUnsold) });
    }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const getPurchaseOrders = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await inventoryService.getPurchaseOrders((req as any).shopId, +(req.query.page || 1), +(req.query.limit || 20)) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const createPurchaseOrder = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await inventoryService.createPurchaseOrder((req as any).shopId, req.body) }); }
    catch (e: any) { res.status(e instanceof PurchaseOrderInputError || String(e.message || '').startsWith('Validation:') ? 400 : 500).json({ success: false, message: e.message }); }
};

export const updatePurchaseOrder = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await inventoryService.updatePurchaseOrder((req as any).shopId, +req.params.id, req.body) }); }
    catch (e: any) { res.status(e instanceof PurchaseOrderInputError || String(e.message || '').startsWith('Validation:') ? 400 : 500).json({ success: false, message: e.message }); }
};

export const deletePurchaseOrder = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await inventoryService.deletePurchaseOrder((req as any).shopId, +req.params.id) }); }
    catch (e: any) { res.status(String(e.message || '').startsWith('Validation:') ? 400 : 500).json({ success: false, message: e.message }); }
};

export const getStockTakes = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await inventoryService.getStockTakes((req as any).shopId, +(req.query.page || 1), +(req.query.limit || 20)) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const createStockTake = async (req: Request, res: Response) => {
    try {
        res.json({ success: true, data: await inventoryService.createStockTake((req as any).shopId, req.body) });
    }
    catch (e: any) { res.status(e instanceof StockTakeInputError || String(e.message || '').startsWith('Validation:') ? 400 : 500).json({ success: false, message: e.message }); }
};

export const updateStockTake = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await inventoryService.updateStockTake((req as any).shopId, +req.params.id, req.body) }); }
    catch (e: any) { res.status(e instanceof StockTakeInputError || String(e.message || '').startsWith('Validation:') ? 400 : 500).json({ success: false, message: e.message }); }
};

export const deleteStockTake = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await inventoryService.deleteStockTake((req as any).shopId, +req.params.id) }); }
    catch (e: any) { res.status(String(e.message || '').startsWith('Validation:') ? 400 : 500).json({ success: false, message: e.message }); }
};
