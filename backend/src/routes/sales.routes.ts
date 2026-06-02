import { Router } from 'express';
import * as salesCtrl from '../controllers/sales.controller';
import { requirePermission } from '../middleware/permission.middleware';

const router = Router();

import { lockTransactionMiddleware } from '../middleware/lock-transaction.middleware';
router.use(lockTransactionMiddleware);

router.get('/sales-orders', requirePermission('sales', 'view'), salesCtrl.findAll);
router.get('/sales-orders/summary', requirePermission('sales', 'view'), salesCtrl.summary);
router.get('/sales-orders/top-products', requirePermission('sales', 'view'), salesCtrl.topProducts);
router.get('/sales-orders/:id', requirePermission('sales', 'view'), salesCtrl.findOne);
router.post('/sales-orders', requirePermission('sales', 'edit'), salesCtrl.create);
router.put('/sales-orders/:id', requirePermission('sales', 'edit'), salesCtrl.updateOrder);
router.post('/sales-orders/:id/cancel', requirePermission('sales', 'edit'), salesCtrl.cancel);
router.post('/sales-orders/:id/payments', requirePermission('sales', 'edit'), salesCtrl.addPayment);
router.post('/sales-orders/:id/returns', requirePermission('sales', 'edit'), salesCtrl.createReturn);

export default router;
