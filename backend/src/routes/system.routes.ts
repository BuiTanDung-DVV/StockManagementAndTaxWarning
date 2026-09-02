import { Router, raw } from 'express';
import * as systemCtrl from '../controllers/system.controller';
import { requirePermission } from '../middleware/permission.middleware';
import * as invoiceOcrCtrl from '../controllers/invoice-ocr.controller';

const router = Router();

// Shop Profile
router.get('/shop-profile', requirePermission('settings', 'view'), systemCtrl.getShopProfile);
router.post('/shop-profile', requirePermission('settings', 'edit'), systemCtrl.saveShopProfile);
router.get('/payment-banks', requirePermission('settings', 'view'), systemCtrl.getPaymentBankOptions);
router.get('/tax-reference-data', requirePermission('finance', 'view'), systemCtrl.getTaxReferenceData);
router.get('/shop-payment-qr', systemCtrl.getShopPaymentQr);
router.post(
    '/shop-payment-qr/upload',
    requirePermission('settings', 'edit'),
    raw({ type: ['image/jpeg', 'image/png', 'image/webp'], limit: '4mb' }),
    systemCtrl.uploadShopPaymentQrImage,
);
router.post('/shop-payment-qr/confirm', requirePermission('settings', 'edit'), systemCtrl.confirmShopPaymentQrUpload);

// Activity Logs
router.get('/activity-logs', requirePermission('settings', 'view'), systemCtrl.getActivityLogs);

// Invoice Scans
router.get('/invoice-scans', requirePermission('finance', 'view'), systemCtrl.getInvoiceScans);
router.post('/invoice-scans/upload', requirePermission('finance', 'edit'), raw({ type: ['image/jpeg', 'image/png', 'image/webp'], limit: '4mb' }), invoiceOcrCtrl.upload);
router.get('/invoice-scans/:id', requirePermission('finance', 'view'), invoiceOcrCtrl.get);
router.post('/invoice-scans/:id/retry', requirePermission('finance', 'edit'), invoiceOcrCtrl.retry);
router.post('/invoice-scans/:id/confirm', requirePermission('finance', 'edit'), invoiceOcrCtrl.confirm);
router.post('/invoice-scans', requirePermission('finance', 'edit'), systemCtrl.createInvoiceScan);
router.put('/invoice-scans/:id', requirePermission('finance', 'edit'), systemCtrl.updateInvoiceScan);

// AI knowledge base
router.get('/ai-knowledge', requirePermission('settings', 'view'), systemCtrl.getAiKnowledgeDocuments);
router.post('/ai-knowledge', requirePermission('settings', 'edit'), systemCtrl.createAiKnowledgeDocument);
router.put('/ai-knowledge/:id', requirePermission('settings', 'edit'), systemCtrl.updateAiKnowledgeDocument);
router.delete('/ai-knowledge/:id', requirePermission('settings', 'edit'), systemCtrl.deleteAiKnowledgeDocument);

// Dynamic System Configurations
router.get('/configs', requirePermission('settings', 'view'), systemCtrl.getConfigs);
router.post('/configs', requirePermission('settings', 'edit'), systemCtrl.saveConfigs);

export default router;
