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

// Purchase Orders
router.get('/purchase-orders', inventoryCtrl.getPurchaseOrders);
router.post('/purchase-orders', inventoryCtrl.createPurchaseOrder);

// Stock Takes
router.post('/stock-takes', inventoryCtrl.createStockTake);

export default router;
