import { Router } from 'express';
import * as systemCtrl from '../controllers/system.controller';
import { requirePermission } from '../middleware/permission.middleware';

const router = Router();

// Shop Profile
router.get('/shop-profile', requirePermission('settings', 'view'), systemCtrl.getShopProfile);
router.post('/shop-profile', requirePermission('settings', 'edit'), systemCtrl.saveShopProfile);

// Activity Logs
router.get('/activity-logs', requirePermission('settings', 'view'), systemCtrl.getActivityLogs);

// Invoice Scans
router.get('/invoice-scans', requirePermission('finance', 'view'), systemCtrl.getInvoiceScans);
router.post('/invoice-scans', requirePermission('finance', 'edit'), systemCtrl.createInvoiceScan);
router.put('/invoice-scans/:id', requirePermission('finance', 'edit'), systemCtrl.updateInvoiceScan);

// Invoices
router.get('/invoices', requirePermission('finance', 'view'), systemCtrl.getInvoices);
router.get('/invoices/summary', requirePermission('finance', 'view'), systemCtrl.getInvoiceSummary);
router.get('/invoices/:id', requirePermission('finance', 'view'), systemCtrl.getInvoiceById);
router.post('/invoices', requirePermission('finance', 'edit'), systemCtrl.createInvoice);

// Purchases without invoice
router.get('/purchases-without-invoice', requirePermission('finance', 'view'), systemCtrl.getPurchasesWithoutInvoice);
router.post('/purchases-without-invoice', requirePermission('finance', 'edit'), systemCtrl.createPurchaseWithoutInvoice);

export default router;
