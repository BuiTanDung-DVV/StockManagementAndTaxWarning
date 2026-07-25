import { Router } from 'express';
import * as supplierCtrl from '../controllers/supplier.controller';
import { requirePermission } from '../middleware/permission.middleware';

const router = Router();

router.get('/suppliers', requirePermission('suppliers', 'view'), supplierCtrl.findAll);
router.get('/suppliers/:id', requirePermission('suppliers', 'view'), supplierCtrl.findOne);
router.post('/suppliers', requirePermission('suppliers', 'edit'), supplierCtrl.create);
router.put('/suppliers/:id', requirePermission('suppliers', 'edit'), supplierCtrl.update);
router.delete('/suppliers/:id', requirePermission('suppliers', 'full'), supplierCtrl.remove);
router.get('/suppliers/:id/payables', requirePermission(['suppliers', 'finance'], 'view'), supplierCtrl.payables);

export default router;
