import { Router, raw } from 'express';
import * as controller from '../controllers/shop-backup.controller';
import { requireOwner } from '../middleware/permission.middleware';

const router = Router();
router.post('/shop-backups/export', requireOwner, controller.exportBackup);
router.post('/shop-backups/validate', requireOwner, raw({ type: 'application/gzip', limit: '25mb' }), controller.validateBackup);
router.post('/shop-backups/restore', requireOwner, controller.restoreBackup);
router.post('/shop-backups/:id/rollback', requireOwner, controller.rollbackBackup);
export default router;
