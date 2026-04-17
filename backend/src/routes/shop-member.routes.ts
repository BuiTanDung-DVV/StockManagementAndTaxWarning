import { Router } from 'express';
import { authenticateJwt } from '../middleware/auth.middleware';
import * as ctrl from '../controllers/shop-member.controller';

const router = Router();

router.get('/shop-members', authenticateJwt, ctrl.listMembers);
router.post('/shop-members/invite', authenticateJwt, ctrl.inviteMember);
router.put('/shop-members/:id/role', authenticateJwt, ctrl.updateMemberRole);
router.delete('/shop-members/:id', authenticateJwt, ctrl.removeMember);

router.get('/shop-members/pending', authenticateJwt, ctrl.listPending);
router.post('/shop-members/:id/approve', authenticateJwt, ctrl.approveMember);
router.post('/shop-members/:id/reject', authenticateJwt, ctrl.rejectMember);

// For shop switching: returns all shops the current user belongs to
router.get('/my-shops', authenticateJwt, ctrl.getMyShops);

export default router;
