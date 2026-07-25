import { Router } from 'express';
import { TagController } from '../controllers/tag.controller';
import { requirePermission } from '../middleware/permission.middleware';

const router = Router();

router.get('/', requirePermission('products', 'view'), TagController.getAll);
router.post('/', requirePermission('products', 'edit'), TagController.create);
router.put('/:id', requirePermission('products', 'edit'), TagController.update);
router.delete('/:id', requirePermission('products', 'full'), TagController.delete);

export default router;
