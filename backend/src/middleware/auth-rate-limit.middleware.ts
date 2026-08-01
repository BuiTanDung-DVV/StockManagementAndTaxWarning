import { NextFunction, Request, Response } from 'express';
import { rateLimit } from 'express-rate-limit';
import { isAllowedOrigin } from '../config/env.config';

const response = { success: false, message: 'Quá nhiều yêu cầu. Vui lòng thử lại sau', code: 'RATE_LIMITED' };

export const loginRateLimit = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 20,
  standardHeaders: 'draft-8',
  legacyHeaders: false,
  skipSuccessfulRequests: true,
  message: response,
});

export const otpRateLimit = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 10,
  standardHeaders: 'draft-8',
  legacyHeaders: false,
  message: response,
});

export const googleRateLimit = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 20,
  standardHeaders: 'draft-8',
  legacyHeaders: false,
  message: response,
});

export function requireTrustedWebRequest(req: Request, res: Response, next: NextFunction) {
  const carriesWebCookie = req.headers.cookie
    ?.split(';')
    .some(part => part.trim().startsWith('smartstock_refresh='));
  if (req.get('x-client-platform') !== 'web' && !carriesWebCookie) return next();
  const origin = req.get('origin');
  const requestedWith = req.get('x-requested-with');
  if (!origin || !isAllowedOrigin(origin) || requestedWith !== 'XMLHttpRequest') {
    return res.status(403).json({ success: false, message: 'Yêu cầu web không hợp lệ' });
  }
  return next();
}
