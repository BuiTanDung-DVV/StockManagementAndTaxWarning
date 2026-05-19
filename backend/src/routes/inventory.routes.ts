import { Router } from 'express';
import * as inventoryCtrl from '../controllers/inventory.controller';

const router = Router();

// Inventory base routes
router.get('/inventory/stock', inventoryCtrl.getStock);
router.get('/inventory/low-stock', inventoryCtrl.getLowStock);
router.get('/inventory/movements', inventoryCtrl.getMovements);
router.get('/inventory/warehouses', inventoryCtrl.getWarehouses);
router.post('/inventory/warehouses', inventoryCtrl.createWarehouse);
router.get('/inventory/xnt-report', inventoryCtrl.getXntReport);
router.get('/inventory/expiring-products', inventoryCtrl.getExpiringProducts);
router.get('/inventory/slow-moving', inventoryCtrl.getSlowMoving);

// Purchase Orders
router.get('/purchase-orders', inventoryCtrl.getPurchaseOrders);
router.post('/purchase-orders', inventoryCtrl.createPurchaseOrder);
router.put('/purchase-orders/:id', inventoryCtrl.updatePurchaseOrder);
router.delete('/purchase-orders/:id', inventoryCtrl.deletePurchaseOrder);

// Stock Takes
router.get('/stock-takes', inventoryCtrl.getStockTakes);
router.post('/stock-takes', inventoryCtrl.createStockTake);
router.put('/stock-takes/:id', inventoryCtrl.updateStockTake);
router.delete('/stock-takes/:id', inventoryCtrl.deleteStockTake);

export default router;
