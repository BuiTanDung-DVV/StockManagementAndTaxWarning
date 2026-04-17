import { Router } from 'express';
import { register, login, forgotPassword, resetPassword, completeOnboarding, searchShops } from '../controllers/auth.controller';
import { authenticateJwt } from '../middleware/auth.middleware';

const router = Router();

router.post('/register', register);
router.post('/login', login);
router.post('/forgot-password', forgotPassword);
router.post('/reset-password', resetPassword);
router.post('/complete-onboarding', authenticateJwt, completeOnboarding);
router.get('/search-shops', searchShops);

export default router;
