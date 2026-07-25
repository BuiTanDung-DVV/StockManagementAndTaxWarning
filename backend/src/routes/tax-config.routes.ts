import { Router } from 'express';
import * as taxConfigController from '../controllers/tax-config.controller';
import { requirePermission } from '../middleware/permission.middleware';

const router = Router();

router.get('/tax/config', requirePermission('finance', 'view'), taxConfigController.getTaxConfig);
router.put('/tax/config', requirePermission('finance', 'edit'), taxConfigController.updateTaxConfig);

export default router;
