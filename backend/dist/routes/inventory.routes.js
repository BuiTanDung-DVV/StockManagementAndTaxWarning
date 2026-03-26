"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const inventoryCtrl = require("../controllers/inventory.controller");
const router = (0, express_1.Router)();
router.get('/inventory/stock', inventoryCtrl.getStock);
router.get('/inventory/low-stock', inventoryCtrl.getLowStock);
router.get('/inventory/movements', inventoryCtrl.getMovements);
router.get('/inventory/warehouses', inventoryCtrl.getWarehouses);
router.post('/inventory/warehouses', inventoryCtrl.createWarehouse);
router.get('/inventory/xnt-report', inventoryCtrl.getXntReport);
router.get('/inventory/expiring-products', inventoryCtrl.getExpiringProducts);
router.get('/purchase-orders', inventoryCtrl.getPurchaseOrders);
router.post('/purchase-orders', inventoryCtrl.createPurchaseOrder);
router.post('/stock-takes', inventoryCtrl.createStockTake);
exports.default = router;
//# sourceMappingURL=inventory.routes.js.map