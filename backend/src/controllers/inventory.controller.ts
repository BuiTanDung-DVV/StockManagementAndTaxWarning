import { PurchaseWriteError } from '../inventory/purchase-write-authorization';
import { Request, Response } from 'express';
import { InventoryService } from '../services/inventory.service';
import { XntExportInputError } from '../inventory/xnt-export.utils';
import { StockTakeInputError } from '../inventory/stock-take-input.utils';
import { PurchaseOrderInputError } from '../inventory/purchase-order-input.utils';
import { InventoryMasterInputError } from '../inventory/inventory-master-input.utils';
import { normalizePurchaseOrderQuery, PurchaseOrderQueryError } from '../inventory/purchase-order-query.utils';

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

export const exportXntReport = async (req: Request, res: Response) => {
    try {
        res.json({ success: true, data: await inventoryService.exportXntReport((req as any).shopId,
            { from: req.query.from, to: req.query.to, warehouseId: req.query.warehouseId }) });
    } catch (error) {
        const invalid = error instanceof XntExportInputError;
        res.status(invalid ? 400 : 500).json({ success: false,
            message: invalid ? error.message : 'Không thể xuất báo cáo nhập–xuất–tồn. Vui lòng thử lại.' });
    }
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
    try {
        const query = normalizePurchaseOrderQuery(req.query);
        res.json({ success: true, data: await inventoryService.getPurchaseOrders((req as any).shopId,
            query.page, query.limit, query.search, query.status) });
    } catch (error) {
        res.status(error instanceof PurchaseOrderQueryError ? 400 : 500).json({ success: false,
            message: error instanceof PurchaseOrderQueryError ? error.message : 'Không thể tải danh sách đơn nhập.' });
    }
};
export const getPurchaseOrder = async (req: Request, res: Response) => {
    const id = Number(req.params.id);
    if (!/^\d+$/.test(String(req.params.id)) || !Number.isSafeInteger(id) || id <= 0) {
        res.status(400).json({ success: false, message: 'Mã đơn nhập không hợp lệ.' });
        return;
    }
    try {
        const order = await inventoryService.getPurchaseOrder((req as any).shopId, id);
        if (!order) {
            res.status(404).json({ success: false, message: 'Không tìm thấy đơn nhập trong cửa hàng.' });
            return;
        }
        res.json({ success: true, data: order });
    } catch (_) {
        res.status(500).json({ success: false, message: 'Không thể tải chi tiết đơn nhập.' });
    }
};

function sendPurchaseWriteError(res: Response, error: unknown) {
    if (error instanceof PurchaseWriteError) return res.status(error.status).json({ success: false, message: error.message });
    if (error instanceof PurchaseOrderInputError || (error instanceof Error && error.message.startsWith('Validation:'))) return res.status(400).json({ success: false, message: (error as Error).message });
    const code = (error as { code?: string })?.code;
    if (['55P03', '23505', '40001', '40P01'].includes(code || '')) return res.status(409).json({ success: false, message: 'Dữ liệu đơn nhập đang thay đổi; hãy tải lại để kiểm tra trước khi thử tiếp.' });
    console.error('Purchase operation failed', { name: error instanceof Error ? error.name : 'Unknown', code });
    return res.status(500).json({ success: false, message: 'Chưa thể thực hiện thao tác đơn nhập. Hãy tải lại đơn để kiểm tra kết quả.' });
}
const purchaseActor = (req: Request) => ({ id: (req as any).user?.sub, authVersion: (req as any).user?.ver });
const purchaseOrderId = (req: Request) => {
    const value = String(req.params.id || '');
    if (!/^[1-9]\d*$/.test(value) || Number(value) > 2147483647) throw new PurchaseWriteError('Mã đơn nhập không hợp lệ', 400);
    return Number(value);
};

export const createPurchaseOrder = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await inventoryService.createPurchaseOrderForActor((req as any).shopId, req.body, purchaseActor(req)) }); }
    catch (e) { sendPurchaseWriteError(res, e); }
};
export const updatePurchaseOrder = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await inventoryService.updatePurchaseOrderForActor((req as any).shopId, purchaseOrderId(req), req.body, purchaseActor(req)) }); }
    catch (e) { sendPurchaseWriteError(res, e); }
};
export const deletePurchaseOrder = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await inventoryService.deletePurchaseOrderForActor((req as any).shopId, purchaseOrderId(req), purchaseActor(req)) }); }
    catch (e) { sendPurchaseWriteError(res, e); }
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
