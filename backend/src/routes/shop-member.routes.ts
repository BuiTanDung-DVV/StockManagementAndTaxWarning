import { Router } from 'express';
import { authenticateJwt } from '../middleware/auth.middleware';
import { requireOwner } from '../middleware/permission.middleware';
import * as ctrl from '../controllers/shop-member.controller';

const router = Router();

router.get('/shop-members', authenticateJwt, requireOwner, ctrl.listMembers);
router.post('/shop-members/invite', authenticateJwt, requireOwner, ctrl.inviteMember);
router.put('/shop-members/:id/role', authenticateJwt, requireOwner, ctrl.updateMemberRole);
router.delete('/shop-members/:id', authenticateJwt, requireOwner, ctrl.removeMember);

router.get('/shop-members/pending', authenticateJwt, requireOwner, ctrl.listPending);
router.post('/shop-members/:id/approve', authenticateJwt, requireOwner, ctrl.approveMember);
router.post('/shop-members/:id/reject', authenticateJwt, requireOwner, ctrl.rejectMember);

// For shop switching: returns all shops the current user belongs to
// Moved to index.ts to bypass requireShopId

export default router;
