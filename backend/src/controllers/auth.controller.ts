import { Request, Response } from 'express';
import { output, ZodError, ZodTypeAny } from 'zod';
import { AuthError } from '../auth/auth.errors';
import {
  forgotPasswordSchema,
  completeOnboardingSchema,
  googleAuthSchema,
  loginSchema,
  refreshTokenSchema,
  registerSchema,
  resetPasswordSchema,
  sendOtpSchema,
} from '../auth/auth.schemas';
import { AuthService } from '../services/auth.service';
import { config } from '../config/env.config';

const authService = new AuthService();
const REFRESH_COOKIE = 'smartstock_refresh';
const REFRESH_COOKIE_PATH = '/api/auth';

function parseBody<T extends ZodTypeAny>(schema: T, body: unknown): output<T> {
  return schema.parse(body);
}

function readCookie(req: Request, name: string): string | undefined {
  const raw = req.headers.cookie;
  if (!raw) return undefined;
  for (const part of raw.split(';')) {
    const separator = part.indexOf('=');
    if (separator < 0 || part.slice(0, separator).trim() !== name) continue;
    try {
      return decodeURIComponent(part.slice(separator + 1).trim());
    } catch {
      return undefined;
    }
  }
  return undefined;
}

function isWebClient(req: Request): boolean {
  return req.get('x-client-platform') === 'web';
}

function cookieOptions() {
  const production = process.env.NODE_ENV === 'production';
  return {
    httpOnly: true,
    secure: production,
    sameSite: production ? 'none' as const : 'lax' as const,
    path: REFRESH_COOKIE_PATH,
    maxAge: config.refreshTokenExpiresInDays * 24 * 60 * 60 * 1000,
  };
}

function clearRefreshCookie(res: Response): void {
  const { maxAge: _maxAge, ...options } = cookieOptions();
  res.clearCookie(REFRESH_COOKIE, options);
}

function sendAuth(req: Request, res: Response, result: Record<string, any>, message: string) {
  if (isWebClient(req)) {
    res.cookie(REFRESH_COOKIE, result.refresh_token, cookieOptions());
    const { refresh_token: _hidden, ...safeResult } = result;
    return res.json({ success: true, data: safeResult, message });
  }
  return res.json({ success: true, data: result, message });
}

function handleError(res: Response, error: unknown): void {
  if (error instanceof ZodError) {
    res.status(422).json({
      success: false,
      message: error.issues[0]?.message || 'Dữ liệu không hợp lệ',
      code: 'VALIDATION_ERROR',
    });
    return;
  }
  if (error instanceof AuthError) {
    res.status(error.statusCode).json({ success: false, message: error.message, code: error.code });
    return;
  }
  console.error('Authentication error:', error instanceof Error ? error.message : 'Unknown error');
  res.status(500).json({ success: false, message: 'Lỗi máy chủ nội bộ' });
}

export const register = async (req: Request, res: Response) => {
  try {
    const result = await authService.register(parseBody(registerSchema, req.body));
    sendAuth(req, res, result, 'Đăng ký thành công');
  } catch (error) {
    handleError(res, error);
  }
};

export const login = async (req: Request, res: Response) => {
  try {
    const result = await authService.login(parseBody(loginSchema, req.body));
    sendAuth(req, res, result, 'Đăng nhập thành công');
  } catch (error) {
    handleError(res, error);
  }
};

export const googleAuth = async (req: Request, res: Response) => {
  try {
    const result = await authService.googleAuth(parseBody(googleAuthSchema, req.body));
    sendAuth(req, res, result, 'Xác thực Google thành công');
  } catch (error) {
    handleError(res, error);
  }
};

export const refreshToken = async (req: Request, res: Response) => {
  try {
    const body = parseBody(refreshTokenSchema, req.body || {});
    const token = body.refresh_token || readCookie(req, REFRESH_COOKIE);
    const result = await authService.refreshToken(token || '');
    if (isWebClient(req)) {
      res.cookie(REFRESH_COOKIE, result.refresh_token, cookieOptions());
      return res.json({
        success: true,
        data: { access_token: result.access_token },
        message: 'Đã làm mới phiên',
      });
    }
    return res.json({ success: true, data: result, message: 'Đã làm mới phiên' });
  } catch (error) {
    handleError(res, error);
  }
};

export const logout = async (req: Request, res: Response) => {
  try {
    const body = parseBody(refreshTokenSchema, req.body || {});
    await authService.logout(body.refresh_token || readCookie(req, REFRESH_COOKIE));
    clearRefreshCookie(res);
    res.json({ success: true, data: { loggedOut: true }, message: 'Đăng xuất thành công' });
  } catch (error) {
    handleError(res, error);
  }
};

export const forgotPassword = async (req: Request, res: Response) => {
  try {
    const data = await authService.forgotPassword(parseBody(forgotPasswordSchema, req.body));
    res.json({ success: true, data, message: 'Nếu Gmail tồn tại, mã OTP sẽ được gửi' });
  } catch (error) {
    handleError(res, error);
  }
};

export const resetPassword = async (req: Request, res: Response) => {
  try {
    const data = await authService.resetPassword(parseBody(resetPasswordSchema, req.body));
    res.json({ success: true, data, message: 'Đã cập nhật mật khẩu' });
  } catch (error) {
    handleError(res, error);
  }
};

export const sendOtp = async (req: Request, res: Response) => {
  try {
    const data = await authService.sendOtp(parseBody(sendOtpSchema, req.body));
    res.json({ success: true, data, message: data.message });
  } catch (error) {
    handleError(res, error);
  }
};

export const completeOnboarding = async (req: Request, res: Response) => {
  try {
    const userId = (req as any).user?.sub;
    if (!userId) return res.status(401).json({ success: false, message: 'Unauthorized' });
    const result = await authService.completeOnboarding(
      userId,
      parseBody(completeOnboardingSchema, req.body),
    );
    return res.json({ success: true, data: result, message: 'Onboarding completed successfully' });
  } catch (error) {
    handleError(res, error);
  }
};

export const searchShops = async (req: Request, res: Response) => {
  try {
    const query = typeof req.query.q === 'string' ? req.query.q : '';
    const shops = await authService.searchShops(query);
    res.json({ success: true, data: shops, message: 'Shops retrieved successfully' });
  } catch (error) {
    handleError(res, error);
  }
};
