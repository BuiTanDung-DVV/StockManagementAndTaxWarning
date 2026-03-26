import { Router } from 'express';
import { authenticateJwt } from '../middleware/auth.middleware';
import * as ctrl from '../controllers/shop-role.controller';

const router = Router();

router.get('/shop-roles', authenticateJwt, ctrl.listRoles);
router.get('/shop-roles/:id', authenticateJwt, ctrl.getRole);
router.post('/shop-roles', authenticateJwt, ctrl.createRole);
router.put('/shop-roles/:id', authenticateJwt, ctrl.updateRole);
router.delete('/shop-roles/:id', authenticateJwt, ctrl.deleteRole);

export default router;
