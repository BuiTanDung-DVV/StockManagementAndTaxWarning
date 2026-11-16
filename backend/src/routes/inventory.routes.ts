import { Router } from 'express';
import * as inventoryCtrl from '../controllers/inventory.controller';
import * as inventoryShelfCtrl from '../controllers/inventory-shelf.controller';
import * as inventoryLoanCtrl from '../controllers/inventory-loan.controller';
import { requirePermission } from '../middleware/permission.middleware';

const router = Router();

import { lockTransactionMiddleware } from '../middleware/lock-transaction.middleware';
router.use(lockTransactionMiddleware);

// Inventory base routes
router.get('/inventory/shelf-positions', requirePermission('inventory', 'view'), inventoryShelfCtrl.list);
router.put('/inventory/shelf-positions', requirePermission('inventory', 'edit'), inventoryShelfCtrl.save);
router.get('/inventory/loans', requirePermission('inventory', 'view'), inventoryLoanCtrl.list);
router.post('/inventory/loans', requirePermission('inventory', 'edit'), inventoryLoanCtrl.request);
router.post('/inventory/loans/:id/shipments', requirePermission('inventory', 'edit'), inventoryLoanCtrl.ship);
router.post('/inventory/loan-shipments/:id/receipts', requirePermission('inventory', 'edit'), inventoryLoanCtrl.receive);
router.get('/inventory/stock', requirePermission('inventory', 'view', { allowAllShops: true }), inventoryCtrl.getStock);
router.get('/inventory/low-stock', requirePermission('inventory', 'view', { allowAllShops: true }), inventoryCtrl.getLowStock);
router.get('/inventory/movements', requirePermission('inventory', 'view'), inventoryCtrl.getMovements);
router.get('/inventory/warehouses', requirePermission('inventory', 'view'), inventoryCtrl.getWarehouses);
router.post('/inventory/warehouses', requirePermission('inventory', 'edit'), inventoryCtrl.createWarehouse);
router.get('/inventory/categories-summary', requirePermission(['inventory', 'dashboard'], 'view', { allowAllShops: true }), inventoryCtrl.getCategoriesSummary);
router.get('/inventory/abc-analysis', requirePermission(['inventory', 'dashboard'], 'view', { allowAllShops: true }), inventoryCtrl.getAbcAnalysis);
router.get('/inventory/xnt-report', requirePermission('inventory', 'view'), inventoryCtrl.getXntReport);
router.get('/inventory/xnt-export', requirePermission('inventory', 'view'), inventoryCtrl.exportXntReport);
router.get('/inventory/expiring-products', requirePermission('inventory', 'view', { allowAllShops: true }), inventoryCtrl.getExpiringProducts);
router.get('/inventory/slow-moving', requirePermission('inventory', 'view', { allowAllShops: true }), inventoryCtrl.getSlowMoving);

// Purchase Orders
router.get('/purchase-orders', requirePermission('inventory', 'view'), inventoryCtrl.getPurchaseOrders);
router.get('/purchase-orders/:id', requirePermission('inventory', 'view'), inventoryCtrl.getPurchaseOrder);
router.post('/purchase-orders', requirePermission('inventory', 'edit'), inventoryCtrl.createPurchaseOrder);
router.put('/purchase-orders/:id', requirePermission('inventory', 'edit'), inventoryCtrl.updatePurchaseOrder);
router.delete('/purchase-orders/:id', requirePermission('inventory', 'edit'), inventoryCtrl.deletePurchaseOrder);

// Stock Takes
router.get('/stock-takes', requirePermission('inventory', 'view'), inventoryCtrl.getStockTakes);
router.post('/stock-takes', requirePermission('inventory', 'edit'), inventoryCtrl.createStockTake);
router.put('/stock-takes/:id', requirePermission('inventory', 'edit'), inventoryCtrl.updateStockTake);
router.delete('/stock-takes/:id', requirePermission('inventory', 'edit'), inventoryCtrl.deleteStockTake);

export default router;
