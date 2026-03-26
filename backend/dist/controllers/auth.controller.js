"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.resetPassword = exports.forgotPassword = exports.login = exports.register = void 0;
const auth_service_1 = require("../services/auth.service");
const authService = new auth_service_1.AuthService();
const register = async (req, res) => {
    try {
        const user = await authService.register(req.body);
        res.json({ success: true, data: user, message: 'Registration successful' });
    }
    catch (error) {
        if (error.message === 'Username already exists') {
            res.status(409).json({ success: false, message: error.message });
        }
        else {
            res.status(500).json({ success: false, message: error.message });
        }
    }
};
exports.register = register;
const login = async (req, res) => {
    try {
        const result = await authService.login(req.body);
        res.json({ success: true, data: result, message: 'Login successful' });
    }
    catch (error) {
        if (error.message === 'Invalid credentials' || error.message === 'Account is inactive') {
            res.status(401).json({ success: false, message: error.message });
        }
        else {
            res.status(500).json({ success: false, message: error.message });
        }
    }
};
exports.login = login;
const forgotPassword = async (req, res) => {
    try {
        const data = await authService.forgotPassword(req.body);
        res.json({ success: true, data, message: 'Forgot password request accepted' });
    }
    catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};
exports.forgotPassword = forgotPassword;
const resetPassword = async (req, res) => {
    try {
        const data = await authService.resetPassword(req.body);
        res.json({ success: true, data, message: 'Password updated' });
    }
    catch (error) {
        if (error.message === 'User not found') {
            res.status(404).json({ success: false, message: error.message });
        }
        else {
            res.status(500).json({ success: false, message: error.message });
        }
    }
};
exports.resetPassword = resetPassword;
//# sourceMappingURL=auth.controller.js.map