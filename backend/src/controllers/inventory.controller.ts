import { Request, Response } from 'express';
import { InventoryService } from '../services/inventory.service';

const inventoryService = new InventoryService();

export const getStock = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await inventoryService.getStock(+(req.query.page || 1), +(req.query.limit || 20)) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const getLowStock = async (req: Request, res: Response) => {
    try { 
        const threshold = req.query.threshold ? +(req.query.threshold) : undefined;
        res.json({ success: true, data: await inventoryService.getLowStock(threshold) }); 
    }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const getMovements = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await inventoryService.getMovements(+(req.query.page || 1), +(req.query.limit || 20)) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const getWarehouses = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await inventoryService.getWarehouses() }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const createWarehouse = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await inventoryService.createWarehouse(req.body) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const getXntReport = async (req: Request, res: Response) => {
    try { 
        const { from, to, warehouseId } = req.query;
        res.json({ 
            success: true, 
            data: await inventoryService.getXntReport(
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
        res.json({ success: true, data: await inventoryService.getExpiringProducts(daysAhead) }); 
    }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const getPurchaseOrders = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await inventoryService.getPurchaseOrders(+(req.query.page || 1), +(req.query.limit || 20)) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const createPurchaseOrder = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await inventoryService.createPurchaseOrder(req.body) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const createStockTake = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await inventoryService.createStockTake(req.body) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
