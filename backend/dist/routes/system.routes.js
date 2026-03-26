"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const systemCtrl = require("../controllers/system.controller");
const router = (0, express_1.Router)();
router.get('/shop-profile', systemCtrl.getShopProfile);
router.post('/shop-profile', systemCtrl.saveShopProfile);
router.get('/activity-logs', systemCtrl.getActivityLogs);
router.get('/invoice-scans', systemCtrl.getInvoiceScans);
router.post('/invoice-scans', systemCtrl.createInvoiceScan);
router.put('/invoice-scans/:id', systemCtrl.updateInvoiceScan);
router.get('/invoices', systemCtrl.getInvoices);
router.get('/invoices/summary', systemCtrl.getInvoiceSummary);
router.get('/invoices/:id', systemCtrl.getInvoiceById);
router.post('/invoices', systemCtrl.createInvoice);
router.get('/purchases-without-invoice', systemCtrl.getPurchasesWithoutInvoice);
router.post('/purchases-without-invoice', systemCtrl.createPurchaseWithoutInvoice);
exports.default = router;
//# sourceMappingURL=system.routes.js.map