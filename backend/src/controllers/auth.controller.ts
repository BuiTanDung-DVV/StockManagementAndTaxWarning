import { Request, Response } from 'express';
import { AuthService } from '../services/auth.service';

const authService = new AuthService();

export const register = async (req: Request, res: Response) => {
    try {
        const user = await authService.register(req.body);
        res.json({ success: true, data: user, message: 'Registration successful' });
    } catch (error: any) {
        if (error.message === 'Username already exists') {
            res.status(409).json({ success: false, message: error.message });
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

export const forgotPassword = async (req: Request, res: Response) => {
    try {
        const data = await authService.forgotPassword(req.body);
        res.json({ success: true, data, message: 'Forgot password request accepted' });
    } catch (error: any) {
        res.status(500).json({ success: false, message: error.message });
    }
};

export const resetPassword = async (req: Request, res: Response) => {
    try {
        const data = await authService.resetPassword(req.body);
        res.json({ success: true, data, message: 'Password updated' });
    } catch (error: any) {
        if (error.message === 'User not found') {
            res.status(404).json({ success: false, message: error.message });
        } else {
            res.status(500).json({ success: false, message: error.message });
        }
    }
};

