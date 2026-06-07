import { Router } from 'express';
import * as inventoryCtrl from '../controllers/inventory.controller';
import { requirePermission } from '../middleware/permission.middleware';

const router = Router();

import { lockTransactionMiddleware } from '../middleware/lock-transaction.middleware';
router.use(lockTransactionMiddleware);

// Inventory base routes
router.get('/inventory/stock', requirePermission('inventory', 'view'), inventoryCtrl.getStock);
router.get('/inventory/low-stock', requirePermission('inventory', 'view'), inventoryCtrl.getLowStock);
router.get('/inventory/movements', requirePermission('inventory', 'view'), inventoryCtrl.getMovements);
router.get('/inventory/warehouses', requirePermission('inventory', 'view'), inventoryCtrl.getWarehouses);
router.post('/inventory/warehouses', requirePermission('inventory', 'edit'), inventoryCtrl.createWarehouse);
router.get('/inventory/categories-summary', requirePermission(['inventory', 'dashboard'], 'view'), inventoryCtrl.getCategoriesSummary);
router.get('/inventory/xnt-report', requirePermission('inventory', 'view'), inventoryCtrl.getXntReport);
router.get('/inventory/expiring-products', requirePermission('inventory', 'view'), inventoryCtrl.getExpiringProducts);
router.get('/inventory/slow-moving', requirePermission('inventory', 'view'), inventoryCtrl.getSlowMoving);

// Purchase Orders
router.get('/purchase-orders', requirePermission('inventory', 'view'), inventoryCtrl.getPurchaseOrders);
router.post('/purchase-orders', requirePermission('inventory', 'edit'), inventoryCtrl.createPurchaseOrder);
router.put('/purchase-orders/:id', requirePermission('inventory', 'edit'), inventoryCtrl.updatePurchaseOrder);
router.delete('/purchase-orders/:id', requirePermission('inventory', 'edit'), inventoryCtrl.deletePurchaseOrder);

// Stock Takes
router.get('/stock-takes', requirePermission('inventory', 'view'), inventoryCtrl.getStockTakes);
router.post('/stock-takes', requirePermission('inventory', 'edit'), inventoryCtrl.createStockTake);
router.put('/stock-takes/:id', requirePermission('inventory', 'edit'), inventoryCtrl.updateStockTake);
router.delete('/stock-takes/:id', requirePermission('inventory', 'edit'), inventoryCtrl.deleteStockTake);

export default router;
