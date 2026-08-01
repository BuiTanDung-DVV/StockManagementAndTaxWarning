import { Router } from 'express';
import {
  completeOnboarding,
  forgotPassword,
  googleAuth,
  login,
  logout,
  refreshToken,
  register,
  resetPassword,
  searchShops,
  sendOtp,
} from '../controllers/auth.controller';
import { authenticateJwt } from '../middleware/auth.middleware';
import {
  googleRateLimit,
  loginRateLimit,
  otpRateLimit,
  requireTrustedWebRequest,
} from '../middleware/auth-rate-limit.middleware';

const router = Router();

router.post('/register', otpRateLimit, requireTrustedWebRequest, register);
router.post('/login', loginRateLimit, requireTrustedWebRequest, login);
router.post('/google', googleRateLimit, requireTrustedWebRequest, googleAuth);
router.post('/forgot-password', otpRateLimit, requireTrustedWebRequest, forgotPassword);
router.post('/reset-password', otpRateLimit, requireTrustedWebRequest, resetPassword);
router.post('/refresh-token', requireTrustedWebRequest, refreshToken);
router.post('/logout', requireTrustedWebRequest, logout);
router.post('/complete-onboarding', authenticateJwt, completeOnboarding);
router.get('/search-shops', authenticateJwt, searchShops);
router.post('/send-otp', otpRateLimit, requireTrustedWebRequest, sendOtp);

export default router;
