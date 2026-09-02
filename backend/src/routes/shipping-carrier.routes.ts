import { Router } from 'express';
import * as controller from '../controllers/shipping-carrier.controller';
import { requirePermission } from '../middleware/permission.middleware';

const router = Router();
router.get('/shipping-carriers', requirePermission('settings', 'view'), controller.list);
router.post('/shipping-carriers', requirePermission('settings', 'edit'), controller.create);
router.put('/shipping-carriers/:id', requirePermission('settings', 'edit'), controller.update);
router.delete('/shipping-carriers/:id', requirePermission('settings', 'edit'), controller.deactivate);
export default router;
