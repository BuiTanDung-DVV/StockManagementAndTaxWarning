import { Request, Response } from 'express';
import { InventoryService } from '../services/inventory.service';

const inventoryService = new InventoryService();

export const getStock = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await inventoryService.getStock((req as any).shopId, +(req.query.page || 1), +(req.query.limit || 20)) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const getLowStock = async (req: Request, res: Response) => {
    try { 
        const threshold = req.query.threshold ? +(req.query.threshold) : undefined;
        res.json({ success: true, data: await inventoryService.getLowStock((req as any).shopId, threshold) }); 
    }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const getMovements = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await inventoryService.getMovements((req as any).shopId, +(req.query.page || 1), +(req.query.limit || 20)) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const getWarehouses = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await inventoryService.getWarehouses((req as any).shopId) }); }
    catch (e: any) { res.status(400).json({ success: false, message: e.message }); }
};

export const createWarehouse = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await inventoryService.createWarehouse((req as any).shopId, req.body) }); }
    catch (e: any) { res.status(400).json({ success: false, message: e.message }); }
};

export const getCategoriesSummary = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await inventoryService.getCategoriesSummary((req as any).shopId) }); }
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
        res.json({ success: true, data: await inventoryService.getExpiringProducts((req as any).shopId, daysAhead) }); 
    }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const getSlowMoving = async (req: Request, res: Response) => {
    try { 
        const daysUnsold = req.query.daysUnsold ? +(req.query.daysUnsold) : 30;
        res.json({ success: true, data: await inventoryService.getSlowMovingProducts((req as any).shopId, daysUnsold) }); 
    }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const getPurchaseOrders = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await inventoryService.getPurchaseOrders((req as any).shopId, +(req.query.page || 1), +(req.query.limit || 20)) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const createPurchaseOrder = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await inventoryService.createPurchaseOrder((req as any).shopId, req.body) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const updatePurchaseOrder = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await inventoryService.updatePurchaseOrder((req as any).shopId, +req.params.id, req.body) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const deletePurchaseOrder = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await inventoryService.deletePurchaseOrder((req as any).shopId, +req.params.id) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const getStockTakes = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await inventoryService.getStockTakes((req as any).shopId, +(req.query.page || 1), +(req.query.limit || 20)) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const createStockTake = async (req: Request, res: Response) => {
    try {
        // Auto-generate stockTakeCode if not provided (entity has NOT NULL unique constraint)
        const dto = {
            ...req.body,
            stockTakeCode: req.body.stockTakeCode || ('ST' + Date.now().toString().slice(-8)),
        };
        res.json({ success: true, data: await inventoryService.createStockTake((req as any).shopId, dto) });
    }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const updateStockTake = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await inventoryService.updateStockTake((req as any).shopId, +req.params.id, req.body) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const deleteStockTake = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await inventoryService.deleteStockTake((req as any).shopId, +req.params.id) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
