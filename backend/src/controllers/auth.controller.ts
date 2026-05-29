import { Request, Response } from 'express';
import { AuthService } from '../services/auth.service';

const authService = new AuthService();

export const register = async (req: Request, res: Response) => {
    try {
        const user = await authService.register(req.body);
        res.json({ success: true, data: user, message: 'Registration successful' });
    } catch (error: any) {
        if (error.message.includes('tồn tại') || error.message.includes('exists')) {
            res.status(409).json({ success: false, message: error.message });
        } else if (error.message.includes('OTP') || error.message.includes('bắt buộc')) {
            res.status(400).json({ success: false, message: error.message });
        } else {
            res.status(500).json({ success: false, message: error.message });
        }
    }
};

export const login = async (req: Request, res: Response) => {
    try {
        const result = await authService.login(req.body);
        // IMPORTANT: Flutter ApiClient._extract() only returns the `data` field.
        // Keep auth responses wrapped inside `data`.
        res.json({ success: true, data: result, message: 'Login successful' });
    } catch (error: any) {
        if (error.message === 'Invalid credentials' || error.message === 'Account is inactive') {
            res.status(401).json({ success: false, message: error.message });
        } else {
            res.status(500).json({ success: false, message: error.message });
        }
    }
};

export const refreshToken = async (req: Request, res: Response) => {
    try {
        const result = await authService.refreshToken(req.body.refresh_token);
        res.json({ success: true, data: result, message: 'Token refreshed' });
    } catch (error: any) {
        res.status(401).json({ success: false, message: error.message });
    }
};

export const forgotPassword = async (req: Request, res: Response) => {
    try {
        const data = await authService.forgotPassword(req.body);
        res.json({ success: true, data, message: 'Forgot password request accepted' });
    } catch (error: any) {
        if (error.message.includes('chưa được đăng ký')) {
            res.status(404).json({ success: false, message: error.message });
        } else if (error.message.includes('Vui lòng nhập')) {
            res.status(400).json({ success: false, message: error.message });
        } else {
            res.status(500).json({ success: false, message: error.message });
        }
    }
};

export const resetPassword = async (req: Request, res: Response) => {
    try {
        const data = await authService.resetPassword(req.body);
        res.json({ success: true, data, message: 'Password updated' });
    } catch (error: any) {
        if (error.message.includes('Không tìm thấy')) {
            res.status(404).json({ success: false, message: error.message });
        } else if (error.message.includes('OTP') || error.message.includes('Vui lòng')) {
            res.status(400).json({ success: false, message: error.message });
        } else {
            res.status(500).json({ success: false, message: error.message });
        }
    }
};
export const completeOnboarding = async (req: Request, res: Response) => {
    try {
        // Assuming authMiddleware is used, req.user holds the token payload
        const userId = (req as any).user?.sub;
        if (!userId) {
            return res.status(401).json({ success: false, message: 'Unauthorized' });
        }
        const result = await authService.completeOnboarding(userId, req.body);
        res.json({ success: true, data: result, message: 'Onboarding completed successfully' });
    } catch (error: any) {
        if (error.message === 'Username already exists') {
            res.status(409).json({ success: false, message: error.message });
        } else {
            res.status(500).json({ success: false, message: error.message });
        }
    }
};

export const searchShops = async (req: Request, res: Response) => {
    try {
        const query = req.query.q as string;
        const shops = await authService.searchShops(query);
        res.json({ success: true, data: shops, message: 'Shops retrieved successfully' });
    } catch (error: any) {
        res.status(500).json({ success: false, message: error.message });
    }
};

export const sendOtp = async (req: Request, res: Response) => {
    try {
        const result = await authService.sendOtp(req.body);
        res.json({ success: true, data: result, message: 'OTP sent successfully' });
    } catch (error: any) {
        res.status(400).json({ success: false, message: error.message });
    }
};
