import { Router } from 'express';
import * as taxCtrl from '../controllers/tax.controller';
import { authenticateJwt } from '../middleware/auth.middleware';
import { requirePermission } from '../middleware/permission.middleware';

const router = Router();
router.use(authenticateJwt);

router.get('/export-htkk', requirePermission('finance', 'view'), taxCtrl.exportToHTKK);
router.get('/estimate', requirePermission('finance', 'view'), taxCtrl.getTaxEstimate);

export default router;
