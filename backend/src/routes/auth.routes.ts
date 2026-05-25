import { Router } from 'express';
import { register, login, forgotPassword, resetPassword, completeOnboarding, searchShops, refreshToken, sendOtp } from '../controllers/auth.controller';
import { authenticateJwt } from '../middleware/auth.middleware';

const router = Router();

router.post('/register', register);
router.post('/login', login);
router.post('/forgot-password', forgotPassword);
router.post('/reset-password', resetPassword);
router.post('/refresh-token', refreshToken);
router.post('/complete-onboarding', authenticateJwt, completeOnboarding);
router.get('/search-shops', searchShops);
router.post('/send-otp', sendOtp);

export default router;
