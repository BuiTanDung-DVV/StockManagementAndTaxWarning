import { Router } from 'express';
import * as systemCtrl from '../controllers/system.controller';

const router = Router();

// Shop Profile
router.get('/shop-profile', systemCtrl.getShopProfile);
router.post('/shop-profile', systemCtrl.saveShopProfile);

// Activity Logs
router.get('/activity-logs', systemCtrl.getActivityLogs);

// Invoice Scans
router.get('/invoice-scans', systemCtrl.getInvoiceScans);
router.post('/invoice-scans', systemCtrl.createInvoiceScan);
router.put('/invoice-scans/:id', systemCtrl.updateInvoiceScan);

// Invoices
router.get('/invoices', systemCtrl.getInvoices);
router.get('/invoices/summary', systemCtrl.getInvoiceSummary);
router.get('/invoices/:id', systemCtrl.getInvoiceById);
router.post('/invoices', systemCtrl.createInvoice);

// Purchases without invoice
router.get('/purchases-without-invoice', systemCtrl.getPurchasesWithoutInvoice);
router.post('/purchases-without-invoice', systemCtrl.createPurchaseWithoutInvoice);

export default router;
