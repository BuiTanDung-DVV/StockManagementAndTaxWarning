import { Router } from 'express';
import { authenticateJwt } from '../middleware/auth.middleware';
import { requireOwner } from '../middleware/permission.middleware';
import * as ctrl from '../controllers/shop-role.controller';

const router = Router();

router.get('/shop-roles', authenticateJwt, requireOwner, ctrl.listRoles);
router.get('/shop-roles/:id', authenticateJwt, requireOwner, ctrl.getRole);
router.post('/shop-roles', authenticateJwt, requireOwner, ctrl.createRole);
router.put('/shop-roles/:id', authenticateJwt, requireOwner, ctrl.updateRole);
router.delete('/shop-roles/:id', authenticateJwt, requireOwner, ctrl.deleteRole);

export default router;
