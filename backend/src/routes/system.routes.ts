import { Router } from 'express';
import * as systemCtrl from '../controllers/system.controller';
import { requireOwner, requirePermission } from '../middleware/permission.middleware';

const router = Router();

// Shop Profile
router.get('/shop-profile', requirePermission('settings', 'view'), systemCtrl.getShopProfile);
router.post('/shop-profile', requirePermission('settings', 'edit'), systemCtrl.saveShopProfile);
router.get('/shop-payment-qr', systemCtrl.getShopPaymentQr);
router.post('/shop-payment-qr/presign', requirePermission('settings', 'edit'), systemCtrl.createShopPaymentQrUpload);
router.post('/shop-payment-qr/confirm', requirePermission('settings', 'edit'), systemCtrl.confirmShopPaymentQrUpload);

// Activity Logs
router.get('/activity-logs', requirePermission('settings', 'view'), systemCtrl.getActivityLogs);

// Invoice Scans
router.get('/invoice-scans', requirePermission('finance', 'view'), systemCtrl.getInvoiceScans);
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

// One-time production test-data task. Remove after the seed is verified.
router.post('/test-media/seed', requireOwner, systemCtrl.seedProductionTestMedia);

export default router;
